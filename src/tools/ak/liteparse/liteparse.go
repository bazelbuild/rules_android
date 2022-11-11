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

// Package liteparse does a light parsing of android resources files that can be used at a later
// stage to generate R.java files.
package liteparse

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path"
	"path/filepath"
	"strings"
	"sync"

	"src/common/golang/flags"
	"src/common/golang/walk"
	rdpb "src/tools/ak/res/proto/res_data_go_proto"
	"src/tools/ak/res/res"
	"src/tools/ak/res/respipe/respipe"
	"src/tools/ak/res/resxml/resxml"
	"src/tools/ak/types"
	"google.golang.org/protobuf/proto"
)

var (
	// Cmd defines the command to run the res parser.
	Cmd = types.Command{
		Init:  Init,
		Run:   Run,
		Desc:  desc,
		Flags: []string{"resourceFiles", "rPbOutput"},
	}

	resourceFiles flags.StringList
	rPbOutput     string
	pkg           string

	initOnce sync.Once
)

const (
	numParsers = 25
)

// Init initializes parse. Flags here need to match flags in AndroidResourceParsingAction.
func Init() {
	initOnce.Do(func() {
		flag.Var(&resourceFiles, "res_files", "Resource files and asset directories to parse.")
		flag.StringVar(&rPbOutput, "out", "", "Path to the output proto file.")
		flag.StringVar(&pkg, "pkg", "", "Java package name.")
	})
}

func desc() string {
	return "Lite parses the resource files to generate an R.pb."
}

// Run runs the parser.
func Run() {
	rscs := ParseAll(context.Background(), resourceFiles, pkg)
	b, err := proto.Marshal(rscs)
	if err != nil {
		log.Fatal(err)
	}
	if err = ioutil.WriteFile(rPbOutput, b, 0644); err != nil {
		log.Fatal(err)
	}
}

type resourceFile struct {
	pathInfo *res.PathInfo
	contents []byte
}

// ParseAll parses all the files in resPaths, which can contain both files and directories,
// and returns pb.
func ParseAll(ctx context.Context, resPaths []string, packageName string) *rdpb.Resources {
	resFiles, err := walk.Files(resPaths)
	if err != nil {
		log.Fatal(err)
	}
	pifs, rscs, err := initializeFileParse(resFiles, packageName)
	if err != nil {
		log.Fatal(err)
	}
	if len(pifs) == 0 {
		return rscs
	}

	piC := make(chan *res.PathInfo, len(pifs))
	for _, pi := range pifs {
		piC <- pi
	}
	close(piC)

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	resC, errC := ResParse(ctx, piC)
	rscs.Resource, err = processResAndErr(resC, errC)
	if err != nil {
		cancel()
		log.Fatal(err)
	}
	return rscs
}

// ResParse consumes a stream of resource paths and converts them into resource protos. These
// protos will only have the minimal name/type info set.
func ResParse(ctx context.Context, piC <-chan *res.PathInfo) (<-chan *rdpb.Resource, <-chan error) {
	parserC := make(chan *res.PathInfo)
	var parsedResCs []<-chan *rdpb.Resource
	var parsedErrCs []<-chan error

	for i := 0; i < numParsers; i++ {
		parsedResC, parsedErrC := xmlParser(ctx, parserC)
		parsedResCs = append(parsedResCs, parsedResC)
		parsedErrCs = append(parsedErrCs, parsedErrC)
	}
	pathResC := make(chan *rdpb.Resource)
	pathErrC := make(chan error)
	go func() {
		defer close(pathResC)
		defer close(pathErrC)
		defer close(parserC)

		for pi := range piC {
			np, err := needsParse(pi)
			if err != nil {
				pathErrC <- err
				return
			} else if np {
				parserC <- pi
			}
			if !parsePathInfo(ctx, pi, pathResC, pathErrC) {
				return
			}
		}
	}()
	parsedResCs = append(parsedResCs, pathResC)
	parsedErrCs = append(parsedErrCs, pathErrC)
	resC := respipe.MergeResStreams(ctx, parsedResCs)
	errC := respipe.MergeErrStreams(ctx, parsedErrCs)

	return resC, errC
}

// ParseAllContents parses all resource files with paths and contents and returns pb representing
// the R class that is generated from the files with the package packageName.
// paths and contents must have the same length, and a file with paths[i] file path
// has file contents contents[i].
func ParseAllContents(ctx context.Context, paths []string, contents [][]byte, packageName string) (*rdpb.Resources, error) {
	if len(paths) != len(contents) {
		return nil, fmt.Errorf("length of paths (%v) and contents (%v) are not equal", len(paths), len(contents))
	}
	pifs, rscs, err := initializeFileParse(paths, packageName)
	if err != nil {
		return nil, err
	}
	if len(pifs) == 0 {
		return rscs, nil
	}

	var rfC []*resourceFile
	for i, pi := range pifs {
		rfC = append(rfC, &resourceFile{
			pathInfo: pi,
			contents: contents[i],
		})
	}

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	resC, errC := resParseContents(ctx, rfC)
	rscs.Resource, err = processResAndErr(resC, errC)
	if err != nil {
		return nil, err
	}
	return rscs, nil
}

// resParseContents consumes resource files and converts them into resource protos.
// These protos will only have the minimal name/type info set.
// The returned channels will be consumed by processRessAndErr.
func resParseContents(ctx context.Context, rfC []*resourceFile) (<-chan *rdpb.Resource, <-chan error) {
	parserC := make(chan *resourceFile)
	var parsedResCs []<-chan *rdpb.Resource
	var parsedErrCs []<-chan error

	for i := 0; i < numParsers; i++ {
		parsedResC, parsedErrC := xmlParserContents(ctx, parserC)
		parsedResCs = append(parsedResCs, parsedResC)
		parsedErrCs = append(parsedErrCs, parsedErrC)
	}
	pathResC := make(chan *rdpb.Resource)
	pathErrC := make(chan error)
	go func() {
		defer close(pathResC)
		defer close(pathErrC)
		defer close(parserC)

		for _, rf := range rfC {
			if needsParseContents(rf.pathInfo, bytes.NewReader(rf.contents)) {
				parserC <- rf
			}
			if !parsePathInfo(ctx, rf.pathInfo, pathResC, pathErrC) {
				return
			}
		}
	}()
	parsedResCs = append(parsedResCs, pathResC)
	parsedErrCs = append(parsedErrCs, pathErrC)
	resC := respipe.MergeResStreams(ctx, parsedResCs)
	errC := respipe.MergeErrStreams(ctx, parsedErrCs)

	return resC, errC
}

// initializeFileParse returns a slice of all PathInfos of files contained in each file path,
// which must be a file (not a directory). It also returns Resources with packageName.
func initializeFileParse(filePaths []string, packageName string) ([]*res.PathInfo, *rdpb.Resources, error) {
	rscs := &rdpb.Resources{
		Pkg: packageName,
	}

	pifs, err := res.MakePathInfos(filePaths)
	if err != nil {
		return nil, nil, err
	}

	return pifs, rscs, nil
}

// parsePathInfo attempts to parse the PathInfo and send the provided Resource and error to the
// provided chan. If the context is canceled, returns false, and otherwise, returns true.
func parsePathInfo(ctx context.Context, pi *res.PathInfo, pathResC chan<- *rdpb.Resource, pathErrC chan<- error) bool {
	if rawName, ok := pathAsRes(pi); ok {
		fqn, err := res.ParseName(rawName, pi.Type)
		if err != nil {
			return respipe.SendErr(ctx, pathErrC, respipe.Errorf(ctx, "%s: name parse failed: %v", pi.Path, err))
		}
		r := new(rdpb.Resource)
		if err := fqn.SetResource(r); err != nil {
			return respipe.SendErr(ctx, pathErrC, respipe.Errorf(ctx, "%s: name->proto failed: %v", fqn, err))
		}
		return respipe.SendRes(ctx, pathResC, r)
	}
	return true
}

// processResAndErr processes the res and err channels and returns the resources if successful
// or the first encountered error.
func processResAndErr(resC <-chan *rdpb.Resource, errC <-chan error) ([]*rdpb.Resource, error) {
	parseErrChan := make(chan error, 1)
	go func() {
		for err := range errC {
			if err != nil {
				parseErrChan <- err
				return
			}
		}
	}()

	doneChan := make(chan struct{}, 1)
	var res []*rdpb.Resource
	go func() {
		for r := range resC {
			res = append(res, r)
		}
		doneChan <- struct{}{}
	}()

	select {
	case err := <-parseErrChan:
		return nil, err
	case <-doneChan:
	}

	return res, nil
}

// xmlParser consumes a stream of paths that need to have their xml contents parsed into resource
// protos. We only need to get names and types - so the parsing is very quick.
func xmlParser(ctx context.Context, piC <-chan *res.PathInfo) (<-chan *rdpb.Resource, <-chan error) {
	resC := make(chan *rdpb.Resource)
	errC := make(chan error)
	go func() {
		defer close(resC)
		defer close(errC)
		for p := range piC {
			if !syncParse(respipe.PrefixErr(ctx, fmt.Sprintf("%s xml-parse: ", p.Path)), p, resC, errC) {
				// ctx must have been canceled - exit.
				return
			}
		}
	}()
	return resC, errC
}

// xmlParserContents consumes a stream of resource files that need to have their xml contents
// parsed into resource protos. We only need to get names and types - so the parsing is very quick.
func xmlParserContents(ctx context.Context, rfC <-chan *resourceFile) (<-chan *rdpb.Resource, <-chan error) {
	resC := make(chan *rdpb.Resource)
	errC := make(chan error)
	go func() {
		defer close(resC)
		defer close(errC)
		for rf := range rfC {
			if !syncParseContents(respipe.PrefixErr(ctx, fmt.Sprintf("%s xml-parse: ", rf.pathInfo.Path)), rf.pathInfo, bytes.NewReader(rf.contents), resC, errC) {
				// ctx must have been canceled - exit.
				return
			}
		}
	}()
	return resC, errC
}

func syncParse(ctx context.Context, p *res.PathInfo, resC chan<- *rdpb.Resource, errC chan<- error) bool {
	f, err := os.Open(p.Path)
	if err != nil {
		return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "open failed: %v", err))
	}
	defer f.Close()
	return syncParseContents(ctx, p, f, resC, errC)
}

func syncParseContents(ctx context.Context, p *res.PathInfo, fileReader io.Reader, resC chan<- *rdpb.Resource, errC chan<- error) bool {
	parsedResC, mergedErrC := parseContents(ctx, p, fileReader)
	for parsedResC != nil || mergedErrC != nil {
		select {
		case r, ok := <-parsedResC:
			if !ok {
				parsedResC = nil
				continue
			}
			if !respipe.SendRes(ctx, resC, r) {
				return false
			}
		case e, ok := <-mergedErrC:
			if !ok {
				mergedErrC = nil
				continue
			}
			if !respipe.SendErr(ctx, errC, e) {
				return false
			}
		}

	}
	return true
}

func parseContents(ctx context.Context, filePathInfo *res.PathInfo, fileReader io.Reader) (resC <-chan *rdpb.Resource, errC <-chan error) {
	xmlC, xmlErrC := resxml.StreamDoc(ctx, fileReader)
	var parsedErrC <-chan error
	if filePathInfo.Type == res.ValueType {
		ctx := respipe.PrefixErr(ctx, "mini-values-parse: ")
		resC, parsedErrC = valuesParse(ctx, xmlC)
	} else {
		ctx := respipe.PrefixErr(ctx, "mini-non-values-parse: ")
		resC, parsedErrC = nonValuesParse(ctx, xmlC)
	}
	errC = respipe.MergeErrStreams(ctx, []<-chan error{parsedErrC, xmlErrC})
	return resC, errC
}

// needsParse determines if a path needs to have a values / nonvalues xml parser run to extract
// resource information.
func needsParse(pi *res.PathInfo) (bool, error) {
	r, err := os.Open(pi.Path)
	if err != nil {
		return false, fmt.Errorf("Unable to open file %s: %s", pi.Path, err)
	}
	defer r.Close()

	return needsParseContents(pi, r), nil
}

// needsParseContents determines if a path with the corresponding reader for contents needs to have a
// values / nonvalues xml parser run to extract resource information.
func needsParseContents(pi *res.PathInfo, r io.Reader) bool {
	if pi.Type == res.Raw {
		return false
	}
	if filepath.Ext(pi.Path) == ".xml" {
		return true
	}
	if filepath.Ext(pi.Path) == "" {
		var header [5]byte
		_, err := io.ReadFull(r, header[:])
		if err != nil && err != io.EOF {
			log.Fatal("Unable to read file %s: %s", pi.Path, err)
		}
		if string(header[:]) == "<?xml" {
			return true
		}
	}
	return false
}

// pathAsRes determines if a particular res.PathInfo is also a standalone resource.
func pathAsRes(pi *res.PathInfo) (string, bool) {
	if pi.Type.Kind() == res.Value || (pi.Type.Kind() == res.Both && strings.HasPrefix(pi.TypeDir, "values")) {
		return "", false
	}
	p := path.Base(pi.Path)
	// Only split on last index of dot when the resource is of RAW type.
	// Some drawable resources (Nine-Patch files) ends with .9.png which should not
	// be included in the resource name.
	if dot := strings.LastIndex(p, "."); dot >= 0 && pi.Type == res.Raw {
		return p[:dot], true
	}
	if dot := strings.Index(p, "."); dot >= 0 {
		return p[:dot], true
	}
	return p, true
}
