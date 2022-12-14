// Copyright 2018 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package bucketize

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"

	"src/common/golang/shard"
	"src/common/golang/xml2"
	"src/tools/ak/res/res"
)

// Helper struct to sort paths by index
type indexedPaths struct {
	order map[string]int
	ps    []string
}

type byPathIndex indexedPaths

func (b byPathIndex) Len() int      { return len(b.ps) }
func (b byPathIndex) Swap(i, j int) { b.ps[i], b.ps[j] = b.ps[j], b.ps[i] }
func (b byPathIndex) Less(i, j int) bool {
	iIdx := pathIdx(b.ps[i], b.order)
	jIdx := pathIdx(b.ps[j], b.order)
	// Files exist in the same directory
	if iIdx == jIdx {
		return b.ps[i] < b.ps[j]
	}
	return iIdx < jIdx
}

// Helper struct to sort valuesKeys by index
type indexedValuesKeys struct {
	order map[string]int
	ks    []valuesKey
}

type byValueKeyIndex indexedValuesKeys

func (b byValueKeyIndex) Len() int      { return len(b.ks) }
func (b byValueKeyIndex) Swap(i, j int) { b.ks[i], b.ks[j] = b.ks[j], b.ks[i] }
func (b byValueKeyIndex) Less(i, j int) bool {
	iIdx := pathIdx(b.ks[i].sourcePath.Path, b.order)
	jIdx := pathIdx(b.ks[j].sourcePath.Path, b.order)
	// Files exist in the same directory
	if iIdx == jIdx {
		return b.ks[i].sourcePath.Path < b.ks[j].sourcePath.Path
	}
	return iIdx < jIdx
}

type valuesKey struct {
	sourcePath res.PathInfo
	resType    res.Type
}

// PartitionSession consumes resources and partitions them into archives by the resource type.
// The typewise partitions can be further sharded by the provided shardFn
type PartitionSession struct {
	typedOutput    map[res.Type][]*zip.Writer
	sharder        shard.Func
	collectedVals  map[valuesKey]map[string][]byte
	collectedPaths map[string]res.PathInfo
	collectedRAs   map[string][]xml.Attr
	resourceOrder  map[string]int
}

// Partitioner takes the provided resource values and paths and stores the data sharded
type Partitioner interface {
	Close() error
	CollectValues(vr *res.ValuesResource) error
	CollectPathResource(src res.PathInfo)
	CollectResourcesAttribute(attr *ResourcesAttribute)
}

// makePartitionSession creates a PartitionSession that writes to the given outputs.
func makePartitionSession(outputs map[res.Type][]io.Writer, sharder shard.Func, resourceOrder map[string]int) (*PartitionSession, error) {
	typeToArchs := make(map[res.Type][]*zip.Writer)
	for t, ws := range outputs {
		archs := make([]*zip.Writer, 0, len(ws))
		for _, w := range ws {
			archs = append(archs, zip.NewWriter(w))
		}
		typeToArchs[t] = archs
	}
	return &PartitionSession{
		typeToArchs,
		sharder,
		make(map[valuesKey]map[string][]byte),
		make(map[string]res.PathInfo),
		make(map[string][]xml.Attr),
		resourceOrder,
	}, nil
}

// Close finalizes all archives in this partition session.
func (ps *PartitionSession) Close() error {
	if err := ps.flushCollectedPaths(); err != nil {
		return fmt.Errorf("got error flushing collected paths: %v", err)
	}
	if err := ps.flushCollectedVals(); err != nil {
		return fmt.Errorf("got error flushing collected values: %v", err)
	}
	// close archives.
	for _, as := range ps.typedOutput {
		for _, a := range as {
			if err := a.Close(); err != nil {
				return fmt.Errorf("%s: could not close: %v", a, err)
			}
		}
	}
	return nil
}

// CollectPathResource takes a file system resource and tracks it so that it can be stored in an output partition and shard.
func (ps *PartitionSession) CollectPathResource(src res.PathInfo) {
	// store the path only if the type is accepted by the underlying partitions.
	if ps.isTypeAccepted(src.Type) {
		ps.collectedPaths[src.Path] = src
	}
}

// CollectValues stores the xml representation of a particular resource from a particular file.
func (ps *PartitionSession) CollectValues(vr *res.ValuesResource) error {
	// store the value only if the type is accepted by the underlying partitions.
	if ps.isTypeAccepted(vr.N.Type) {
		// Don't store style attr's from other packages
		if !(vr.N.Type == res.Attr && vr.N.Package != "res-auto") {
			k := valuesKey{*vr.Src, vr.N.Type}
			if tv, ok := ps.collectedVals[k]; !ok {
				ps.collectedVals[k] = make(map[string][]byte)
				ps.collectedVals[k][vr.N.String()] = vr.Payload
			} else {
				if p, ok := tv[vr.N.String()]; !ok {
					ps.collectedVals[k][vr.N.String()] = vr.Payload
				} else if len(p) < len(vr.Payload) {
					ps.collectedVals[k][vr.N.String()] = vr.Payload
				} else if len(p) == len(vr.Payload) && bytes.Compare(p, vr.Payload) != 0 {
					return fmt.Errorf("different values for resource %q", vr.N.String())
				}
			}
		}
	}
	return nil
}

// CollectResourcesAttribute stores the xml attributes of the resources tag from a particular file.
func (ps *PartitionSession) CollectResourcesAttribute(ra *ResourcesAttribute) {
	ps.collectedRAs[ra.ResFile.Path] = append(ps.collectedRAs[ra.ResFile.Path], ra.Attribute)
}

func (ps *PartitionSession) isTypeAccepted(t res.Type) bool {
	_, ok := ps.typedOutput[t]
	return ok
}

func (ps *PartitionSession) flushCollectedPaths() error {
	// sort keys so that data is written to the archives in a deterministic order
	// specifically the same order in which they were declared
	ks := make([]string, 0, len(ps.collectedPaths))
	for k := range ps.collectedPaths {
		ks = append(ks, k)
	}
	sort.Sort(byPathIndex(indexedPaths{order: ps.resourceOrder, ps: ks}))
	for _, k := range ks {
		v := ps.collectedPaths[k]
		f, err := os.Open(v.Path)
		if err != nil {
			return fmt.Errorf("%s: could not be opened for reading: %v", v.Path, err)
		}
		if err := ps.storePathResource(v, f); err != nil {
			return fmt.Errorf("%s: got error storing path resource: %v", v.Path, err)
		}
		f.Close()
	}
	return nil
}

func (ps *PartitionSession) storePathResource(src res.PathInfo, r io.Reader) error {
	p := path.Base(src.Path)
	if dot := strings.Index(p, "."); dot == 0 {
		// skip files where the name starts with a ".", these are already ignored by aapt
		return nil
	} else if dot > 0 {
		p = p[:dot]
	}
	fqn, err := res.ParseName(p, src.Type)
	if err != nil {
		return fmt.Errorf("%s: %q could not be parsed into a res name: %v", src.Path, p, err)
	}
	arch, err := ps.archiveFor(fqn)
	if err != nil {
		return fmt.Errorf("%s: could not get partitioned archive: %v", src.Path, err)
	}
	w, err := arch.Create(pathResSuffix(src.Path))
	if err != nil {
		return fmt.Errorf("%s: could not create writer: %v", src.Path, err)
	}
	if _, err = io.Copy(w, r); err != nil {
		return fmt.Errorf("%s: could not copy into archive: %v", src.Path, err)
	}
	return nil
}

func (ps *PartitionSession) archiveFor(fqn res.FullyQualifiedName) (*zip.Writer, error) {
	archs, ok := ps.typedOutput[fqn.Type]
	if !ok {
		return nil, fmt.Errorf("%s: do not have output stream for this res type", fqn.Type)
	}
	shard := ps.sharder(fqn.String(), len(archs))
	if shard > len(archs) || 0 > shard {
		return nil, fmt.Errorf("%v: bad sharder f(%v, %d) -> %d must be [0,%d)", ps.sharder, fqn, len(archs), shard, len(archs))
	}
	return archs[shard], nil
}

var (
	resXMLHeader = []byte("<?xml version='1.0' encoding='utf-8'?>")
	resXMLFooter = []byte("</resources>")
)

func (ps *PartitionSession) flushCollectedVals() error {
	// sort keys so that data is written to the archives in a deterministic order
	// specifically the same order in which blaze provides them
	ks := make([]valuesKey, 0, len(ps.collectedVals))
	for k := range ps.collectedVals {
		ks = append(ks, k)
	}
	sort.Sort(byValueKeyIndex(indexedValuesKeys{order: ps.resourceOrder, ks: ks}))
	for _, k := range ks {
		as, ok := ps.typedOutput[k.resType]
		if !ok {
			return fmt.Errorf("%s: no output for res type", k.resType)
		}
		ws := make([]io.Writer, 0, len(as))
		// For each given source file, create a corresponding file in each of the shards. A file in a particular shard may be empty, if none of the resources defined in the source file ended up in that shard.
		for _, a := range as {
			w, err := a.Create(pathResSuffix(k.sourcePath.Path))
			if err != nil {
				return fmt.Errorf("%s: could not create entry: %v", k.sourcePath.Path, err)
			}
			if _, err = w.Write(resXMLHeader); err != nil {
				return fmt.Errorf("%s: could not write xml header: %v", k.sourcePath.Path, err)
			}
			// Write the resources open tag, with the attributes collected.
			b := bytes.Buffer{}
			xml2.NewEncoder(&b).EncodeToken(xml.StartElement{
				Name: res.ResourcesTagName,
				Attr: ps.collectedRAs[k.sourcePath.Path],
			})
			if _, err = w.Write(b.Bytes()); err != nil {
				return fmt.Errorf("%s: could not write resources tag %q: %v", k.sourcePath.Path, b.String(), err)
			}
			ws = append(ws, w)
		}
		v := ps.collectedVals[k]
		var keys []string
		for k := range v {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, fqn := range keys {
			p := v[fqn]
			shard := ps.sharder(fqn, len(ws))
			if shard < 0 || shard >= len(ws) {
				return fmt.Errorf("%v: bad sharder f(%s, %d) -> %d must be [0,%d)", ps.sharder, fqn, len(ws), shard, len(ws))
			}
			if _, err := ws[shard].Write(p); err != nil {
				return fmt.Errorf("%s: writing resource %s failed: %v", k.sourcePath.Path, fqn, err)
			}
		}
		for _, w := range ws {
			if _, err := w.Write(resXMLFooter); err != nil {
				return fmt.Errorf("%s: could not write xml footer: %v", k.sourcePath.Path, err)
			}
		}
	}
	return nil
}

func pathIdx(path string, order map[string]int) int {
	if idx, ok := order[path]; ok == true {
		return idx
	}
	// TODO(mauriciogg): maybe replace with prefix search
	// list of resources might contain directories so exact match might not exist
	dirPos := strings.LastIndex(path, "/res/")
	idx, _ := order[path[0:dirPos+4]]
	return idx
}

func pathResSuffix(path string) string {
	// returns the relative resource path from the full path
	// e.g. /foo/bar/res/values/strings.xml -> res/values/strings.xml
	parentDir := filepath.Dir(filepath.Dir(filepath.Dir(path)))
	return strings.TrimPrefix(path, parentDir+string(filepath.Separator))
}
