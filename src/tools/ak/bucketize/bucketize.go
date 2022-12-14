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

// Package bucketize provides functionality to bucketize Android resources.
package bucketize

import (
	"bytes"
	"context"
	"encoding/xml"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path"
	"strings"
	"sync"

	"src/common/golang/flags"
	"src/common/golang/shard"
	"src/common/golang/walk"
	"src/common/golang/xml2"
	"src/tools/ak/akhelper"
	"src/tools/ak/res/res"
	"src/tools/ak/types"
)

const (
	numParsers = 25
)

// Archiver process the provided resource files and directories stores the data
type Archiver struct {
	ResFiles    []*res.PathInfo
	Partitioner Partitioner
}

// ResourcesAttribute correlates the attribute of a resources xml tag and the file where it originates
type ResourcesAttribute struct {
	Attribute xml.Attr
	ResFile   *res.PathInfo
}

var (
	// Cmd defines the command to run repack
	Cmd = types.Command{
		Init: Init,
		Run:  Run,
		Desc: desc,
		Flags: []string{
			"res_paths",
			"typed_outputs",
		},
	}

	resPaths     flags.StringList
	typedOutputs flags.StringList

	initOnce sync.Once
)

// Init initializes repack.
func Init() {
	initOnce.Do(func() {
		flag.Var(&resPaths, "res_paths", "List of res paths (a file or directory).")
		flag.Var(&typedOutputs, "typed_outputs", akhelper.FormatDesc([]string{
			"A list of output file paths, each path prefixed with the res type it supports.",
			"<res_type>:<file_path> i.e. string:/foo/bar/res-string-0.zip,string:/foo/bar/res-string-1.zip,...",
			"The number of files per res type will determine shards."}))
	})
}

func desc() string {
	return "Bucketize Android resources."
}

// MakeArchiver creates an Archiver
func makeArchiver(resFiles []string, p Partitioner) (*Archiver, error) {
	pis, err := res.MakePathInfos(resFiles)
	if err != nil {
		return nil, fmt.Errorf("converting res path failed: %v", err)
	}
	return &Archiver{ResFiles: pis, Partitioner: p}, nil
}

// Archive process the res directories and files of the archiver
func (a *Archiver) Archive(ctx context.Context) error {
	ctx, cancel := context.WithCancel(prefixErr(ctx, "archive: "))
	defer cancel()
	vPIC, nvPIC := separatePathInfosByValues(ctx, a.ResFiles)
	vrCs := make([]<-chan *res.ValuesResource, 0, numParsers)
	raCs := make([]<-chan *ResourcesAttribute, 0, numParsers)
	errCs := make([]<-chan error, 0, numParsers)
	for i := 0; i < numParsers; i++ {
		vrC, raC, vErrC := handleValuesPathInfos(ctx, vPIC)
		vrCs = append(vrCs, vrC)
		raCs = append(raCs, raC)
		errCs = append(errCs, vErrC)
	}
	mVRC := mergeValuesResourceStreams(ctx, vrCs)
	mRAC := mergeResourcesAttributeStreams(ctx, raCs)
	mErrC := mergeErrStreams(ctx, errCs)
	return a.archive(ctx, nvPIC, mVRC, mRAC, mErrC)
}

// archive takes PathInfo, ValuesResource and error channels and process the values given
func (a *Archiver) archive(ctx context.Context, piC <-chan *res.PathInfo, vrC <-chan *res.ValuesResource, raC <-chan *ResourcesAttribute, errC <-chan error) error {
	var errs []error
Loop:
	for piC != nil || vrC != nil || errC != nil || raC != nil {
		select {
		case e, ok := <-errC:
			if !ok {
				errC = nil
				continue
			}
			errs = append(errs, e)
			break Loop
		case ra, ok := <-raC:
			if !ok {
				raC = nil
				continue
			}
			a.Partitioner.CollectResourcesAttribute(ra)
		case pi, ok := <-piC:
			if !ok {
				piC = nil
				continue
			}
			a.Partitioner.CollectPathResource(*pi)
		case vr, ok := <-vrC:
			if !ok {
				vrC = nil
				continue
			}
			if err := a.Partitioner.CollectValues(vr); err != nil {
				return fmt.Errorf("got error collecting values: %v", err)
			}
		}
	}

	if len(errs) != 0 {
		return errorf(ctx, "errors encountered: %v", errs)
	}
	if err := a.Partitioner.Close(); err != nil {
		return fmt.Errorf("got error closing partitioner: %v", err)
	}
	return nil
}

func handleValuesPathInfos(ctx context.Context, piC <-chan *res.PathInfo) (<-chan *res.ValuesResource, <-chan *ResourcesAttribute, <-chan error) {
	vrC := make(chan *res.ValuesResource)
	raC := make(chan *ResourcesAttribute)
	errC := make(chan error)
	go func() {
		defer close(vrC)
		defer close(raC)
		defer close(errC)
		for pi := range piC {
			if !syncParse(prefixErr(ctx, fmt.Sprintf("%s values-parse: ", pi.Path)), pi, vrC, raC, errC) {
				return
			}
		}
	}()
	return vrC, raC, errC
}

func syncParse(ctx context.Context, pi *res.PathInfo, vrC chan<- *res.ValuesResource, raC chan<- *ResourcesAttribute, errC chan<- error) bool {
	f, err := os.Open(pi.Path)
	if err != nil {
		return sendErr(ctx, errC, errorf(ctx, "open failed: %v", err))
	}
	defer f.Close()
	return syncParseReader(ctx, pi, xml.NewDecoder(f), vrC, raC, errC)
}

func syncParseReader(ctx context.Context, pi *res.PathInfo, dec *xml.Decoder, vrC chan<- *res.ValuesResource, raC chan<- *ResourcesAttribute, errC chan<- error) bool {
	// Shadow Encoder is used to track xml state, such as namespaces. The state will be inherited by child encoders.
	parentEnc := xml2.NewEncoder(ioutil.Discard)
	for {
		t, err := dec.Token()
		if err == io.EOF {
			return true
		}
		if err != nil {
			return sendErr(ctx, errC, errorf(ctx, "token failed: %v", err))
		}
		if err := parentEnc.EncodeToken(t); err != nil {
			return sendErr(ctx, errC, errorf(ctx, "encoding token token %s failed: %v", t, err))
		}
		if se, ok := t.(xml.StartElement); ok && se.Name == res.ResourcesTagName {
			for _, xmlAttr := range se.Attr {
				raC <- &ResourcesAttribute{ResFile: pi, Attribute: xmlAttr}
			}
			// AAPT2 does not support a multiple resources sections in a single file and silently ignores
			// subsequent resources sections. The parser will only parse the first resources tag and exit.
			return parseRes(ctx, parentEnc, pi, dec, vrC, errC)
		}
	}
}

func skipTag(se xml.StartElement) bool {
	_, ok := res.ResourcesChildToSkip[se.Name]
	return ok
}

func parseRes(ctx context.Context, parentEnc *xml2.Encoder, pi *res.PathInfo, dec *xml.Decoder, vrC chan<- *res.ValuesResource, errC chan<- error) bool {
	for {
		t, err := dec.Token()
		if err != nil {
			return sendErr(ctx, errC, errorf(ctx, "extract token failed: %v", err))
		}
		// Encode all tokens to the shadow Encoder at the top-level loop to keep track of any required xml state.
		if err := parentEnc.EncodeToken(t); err != nil {
			return sendErr(ctx, errC, errorf(ctx, "encoding token token %s failed: %v", t, err))
		}
		switch t.(type) {
		case xml.StartElement:
			se := t.(xml.StartElement)
			if skipTag(se) {
				dec.Skip()
				break
			}

			fqn, err := extractFQN(se)
			if err != nil {
				return sendErr(ctx, errC, errorf(ctx, "extract name and type failed: %v", err))
			}

			b, err := extractElement(parentEnc, dec, se)
			if err != nil {
				return sendErr(ctx, errC, errorf(ctx, "extracting element failed: %v", err))
			}

			if !sendVR(ctx, vrC, &res.ValuesResource{pi, fqn, b.Bytes()}) {
				return false
			}

			if fqn.Type == res.Styleable {
				// with a declare-styleable tag, parse its childen and treat them as direct children of resources
				dsDec := xml.NewDecoder(b)
				dsDec.Token() // we've already processed the first token (the declare-styleable start element)
				if !parseRes(ctx, parentEnc, pi, dsDec, vrC, errC) {
					return false
				}
			}
		case xml.EndElement:
			return true
		}
	}
}

func extractFQN(se xml.StartElement) (res.FullyQualifiedName, error) {
	if matches(se.Name, res.ItemTagName) {
		nameAttr, resType, err := extractNameAndType(se)
		if err != nil {
			return res.FullyQualifiedName{}, err
		}
		return res.ParseName(nameAttr, resType)
	}

	nameAttr, err := extractName(se)
	if err != nil {
		return res.FullyQualifiedName{}, err
	}
	if resType, ok := res.ResourcesTagToType[se.Name.Local]; ok {
		return res.ParseName(nameAttr, resType)
	}
	return res.FullyQualifiedName{}, fmt.Errorf("%s: is an unhandled tag", se.Name.Local)

}

func extractName(se xml.StartElement) (nameAttr string, err error) {
	for _, a := range se.Attr {
		if matches(res.NameAttrName, a.Name) {
			nameAttr = a.Value
			break
		}
	}
	if nameAttr == "" {
		err = fmt.Errorf("%s: tag is missing %q attribute or is empty", se.Name.Local, res.NameAttrName.Local)
	}
	return
}

func extractNameAndType(se xml.StartElement) (nameAttr string, resType res.Type, err error) {
	var typeAttr string
	for _, a := range se.Attr {
		if matches(res.NameAttrName, a.Name) {
			nameAttr = a.Value
		}
		if matches(res.TypeAttrName, a.Name) {
			typeAttr = a.Value
		}
	}
	if nameAttr == "" {
		err = fmt.Errorf("%s: tag is missing %q attribute or is empty", se.Name.Local, res.NameAttrName.Local)
		return
	}
	if typeAttr == "" {
		err = fmt.Errorf("%s: tag is missing %q attribute or is empty", se.Name.Local, res.TypeAttrName.Local)
		return
	}
	resType, err = res.ParseType(typeAttr)
	return
}

func matches(n1, n2 xml.Name) bool {
	// Ignores xml.Name Space attributes unless both names specify Space.
	if n1.Space == "" || n2.Space == "" {
		return n1.Local == n2.Local
	}
	return n1.Local == n2.Local && n1.Space == n2.Space
}

func extractElement(parentEnc *xml2.Encoder, dec *xml.Decoder, se xml.Token) (*bytes.Buffer, error) {
	// copy tag contents to a buffer
	b := &bytes.Buffer{}
	enc := xml2.ChildEncoder(b, parentEnc)
	if err := enc.EncodeToken(se); err != nil {
		return nil, fmt.Errorf("encoding start element failed: %v", err)
	}
	if err := copyTag(enc, dec); err != nil {
		return nil, fmt.Errorf("copyTag failed: %s", err)
	}
	enc.Flush()
	return b, nil
}

func copyTag(enc *xml2.Encoder, dec *xml.Decoder) error {
	for {
		t, err := dec.Token()
		if err != nil {
			return fmt.Errorf("extract token failed: %v", err)
		}
		if err := enc.EncodeToken(t); err != nil {
			return fmt.Errorf("encoding token %v failed: %v", t, err)
		}
		switch t.(type) {
		case xml.StartElement:
			if err := copyTag(enc, dec); err != nil {
				return err
			}
		case xml.EndElement:
			return nil
		}
	}
}

func sendVR(ctx context.Context, vrC chan<- *res.ValuesResource, vr *res.ValuesResource) bool {
	select {
	case vrC <- vr:
	case <-ctx.Done():
		return false
	}
	return true
}

func hasChildType(dec *xml.Decoder, lookup map[xml.Name]res.Type, want res.Type) (bool, error) {
	for {
		t, err := dec.Token()
		if err != nil {
			return false, fmt.Errorf("extract token failed: %v", err)
		}
		switch t.(type) {
		case xml.StartElement:
			if rt, ok := lookup[t.(xml.StartElement).Name]; ok {
				if rt == want {
					return true, nil
				}
			}
			// when tag is not in the lookup or the type is unknown or "wanted", skip it.
			dec.Skip()
		case xml.EndElement:
			return false, nil
		}
	}
}

func createPartitions(typedOutputs []string) (map[res.Type][]io.Writer, error) {
	partitions := make(map[res.Type][]io.Writer)
	for _, tAndOP := range typedOutputs {
		tOP := strings.SplitN(tAndOP, ":", 2)
		// no shard count override specified
		if len(tOP) == 1 {
			return nil, fmt.Errorf("got malformed typed output path %q wanted the following format \"<type>:<file path>\"", tAndOP)
		}
		t, err := res.ParseType(tOP[0])
		if err != nil {
			return nil, fmt.Errorf("got err while trying to parse %s to a res type: %v", tOP[0], err)
		}
		op := tOP[1]
		if err := os.MkdirAll(path.Dir(op), 0744); err != nil {
			return nil, fmt.Errorf("%s: mkdir failed: %v", op, err)
		}
		f, err := os.OpenFile(op, os.O_CREATE|os.O_RDWR|os.O_TRUNC, 0644)
		if err != nil {
			return nil, fmt.Errorf("open/create failed: %v", err)
		}
		partitions[t] = append(partitions[t], f)
	}
	return partitions, nil
}

// Run is the entry point for bucketize.
func Run() {
	if resPaths == nil || typedOutputs == nil {
		log.Fatal("Flags -res_paths and -typed_outputs must be specified.")
	}

	resFiles, err := walk.Files(resPaths)
	if err != nil {
		log.Fatalf("Got error getting the resource paths: %v", err)
	}
	resFileIdxs := make(map[string]int)
	for i, resFile := range resFiles {
		resFileIdxs[resFile] = i
	}

	p, err := createPartitions(typedOutputs)
	if err != nil {
		log.Fatalf("Got error creating partitions: %v", err)
	}

	ps, err := makePartitionSession(p, shard.FNV, resFileIdxs)
	if err != nil {
		log.Fatalf("Got error making partition session: %v", err)
	}

	m, err := makeArchiver(resFiles, ps)
	if err != nil {
		log.Fatalf("Got error making archiver: %v", err)
	}

	if err := m.Archive(context.Background()); err != nil {
		log.Fatalf("Got error archiving: %v", err)
	}
}
