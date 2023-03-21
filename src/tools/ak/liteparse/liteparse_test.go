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

package liteparse

import (
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"testing"

	"src/common/golang/runfilelocation"
	rdpb "src/tools/ak/res/proto/res_data_go_proto"
	"src/tools/ak/res/res"
	"src/tools/ak/res/respipe/respipe"
	"github.com/google/go-cmp/cmp"
)

const (
	testdata = "src/tools/ak/liteparse/testdata/"
)

func TestPathAsRes(t *testing.T) {
	tests := []struct {
		arg  string
		name string
		ok   bool
	}{
		{
			"foo/bar/res/values/strings.xml",
			"",
			false,
		},
		{
			"foo/bar/res/values-ldpi-v19/strings.xml",
			"",
			false,
		},
		{
			"foo/bar/res/layout-en-US-v19/hello_america.xml",
			"hello_america",
			true,
		},
		{
			"foo/bar/res/xml-land/perfs.xml",
			"perfs",
			true,
		},
		{
			"foo/bar/res/drawable-land/eagle.png",
			"eagle",
			true,
		},
		{
			"foo/bar/res/raw/vid.1080p.png",
			"vid.1080p",
			true,
		},
		{
			"foo/bar/res/drawable-land/circle.9.png",
			"circle",
			true,
		},
	}

	for _, tc := range tests {
		pi, err := res.ParsePath(tc.arg)
		if err != nil {
			t.Errorf("res.ParsePath(%q) returns %v unexpectedly", tc.arg, err)
			continue
		}
		rawName, ok := pathAsRes(&pi)
		if tc.name != rawName || ok != tc.ok {
			t.Errorf("pathAsRes(%v) got %q, %t want %q, %t", pi, rawName, ok, tc.name, tc.ok)
		}
	}
}

func TestNeedsParse(t *testing.T) {
	tests := []struct {
		arg     string
		content string
		want    bool
	}{
		{
			"foo/bar/res/values/strings.xml",
			"",
			true,
		},
		{
			"foo/bar/res/values-ldpi-v19/strings.xml",
			"",
			true,
		},
		{
			"foo/bar/res/layout-en-US-v19/hello_america.xml",
			"",
			true,
		},
		{
			"foo/bar/res/xml-land/perfs.xml",
			"",
			true,
		},
		{
			"foo/bar/res/drawable-land/eagle.png",
			"",
			false,
		},
		{
			"foo/bar/res/drawable-land/eagle",
			"",
			false,
		},
		{
			"foo/bar/res/drawable-land/eagle_xml",
			"<?xml version=\"1.0\" encoding=\"utf-8\"?></xml>",
			true,
		},
		{
			"foo/bar/res/drawable-land/eagle_txt",
			"some non-xml file",
			false,
		},
	}

	for _, tc := range tests {
		f := createTestFile(tc.arg, tc.content)
		defer os.Remove(f)
		pi, err := res.ParsePath(f)
		if err != nil {
			t.Errorf("res.ParsePath(%s) returns %v unexpectedly", f, err)
			continue
		}
		got, err := needsParse(&pi)
		if err != nil {
			t.Errorf("needsParse(%v) returns %v unexpectedly", pi, err)
		}
		if got != tc.want {
			t.Errorf("needsParse(%v) got %t want %t", pi, got, tc.want)
		}
	}
}

func createTestFile(path, content string) string {
	dir := filepath.Dir(path)
	tmpDir, err := ioutil.TempDir("", "test")
	if err != nil {
		log.Fatal(err)
	}
	err = os.MkdirAll(tmpDir+"/"+dir, os.ModePerm)
	if err != nil {
		log.Fatal(err)
	}
	f, err := os.Create(tmpDir + "/" + path)
	if err != nil {
		log.Fatal(err)
	}
	if _, err := f.Write([]byte(content)); err != nil {
		log.Fatal(err)
	}
	if err := f.Close(); err != nil {
		log.Fatal(err)
	}
	return f.Name()
}

func TestParse(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	testRes := createResFile("res")
	piC, pathErrC := respipe.EmitPathInfosDir(ctx, testRes)
	resC, parseErrC := ResParse(ctx, piC)
	errC := respipe.MergeErrStreams(ctx, []<-chan error{pathErrC, parseErrC})
	var parsedNames []string
	for resC != nil || errC != nil {
		select {
		case r, ok := <-resC:
			if !ok {
				resC = nil
				continue
			}
			pn, err := res.ParseName(r.GetName(), res.Type(r.ResourceType))
			if err != nil {
				t.Errorf("res.ParseName(%q, %v) unexpected err: %v", r.GetName(), r.ResourceType, err)
				fmt.Printf("parsename err: %v\n", err)
				continue
			}
			parsedNames = append(parsedNames, pn.String())
		case e, ok := <-errC:
			if !ok {
				errC = nil
				continue
			}
			t.Errorf("Unexpected err: %v", e)
		}
	}
	sort.Strings(parsedNames)
	expectedNames := []string{
		"res-auto:attr/bg",
		"res-auto:attr/size",
		"res-auto:drawable/foo",
		"res-auto:id/item1",
		"res-auto:id/item2",
		"res-auto:id/large",
		"res-auto:id/response",
		"res-auto:id/small",
		"res-auto:menu/simple",
		"res-auto:raw/garbage",
		"res-auto:string/exlusive",
		"res-auto:string/greeting",
		"res-auto:string/lonely",
		"res-auto:string/title",
		"res-auto:string/title2",
		"res-auto:string/version",
		"res-auto:string/version", // yes duplicated (appears in 2 different files, dupes get handled later in the pipeline)
		"res-auto:styleable/absPieChart",
	}
	if !reflect.DeepEqual(parsedNames, expectedNames) {
		t.Errorf("%s: has these resources: %s expected: %s", testRes, parsedNames, expectedNames)
	}
}

func TestParseAll(t *testing.T) {
	tests := []struct {
		resfiles []string
		pkg      string
		want     *rdpb.Resources
	}{
		{
			resfiles: createResfiles([]string{}),
			pkg:      "",
			want:     createResources("", []rdpb.Resource_Type{}, []string{}),
		},
		{
			resfiles: createResfiles([]string{"mini-1"}),
			pkg:      "example",
			want:     createResources("example", []rdpb.Resource_Type{rdpb.Resource_STRING}, []string{"greeting"}),
		},
		{
			resfiles: createResfiles([]string{"mini-2"}),
			pkg:      "com.example",
			want:     createResources("com.example", []rdpb.Resource_Type{rdpb.Resource_XML, rdpb.Resource_ID}, []string{"foo", "foobar"}),
		},
		{
			resfiles: createResfiles([]string{"res/drawable-ldpi/foo.9.png", "res/menu/simple.xml"}),
			pkg:      "com.example",
			want: createResources("com.example",
				[]rdpb.Resource_Type{rdpb.Resource_DRAWABLE, rdpb.Resource_MENU, rdpb.Resource_ID, rdpb.Resource_ID},
				[]string{"foo", "simple", "item1", "item2"}),
		},
	}

	for _, tc := range tests {
		if got := ParseAll(context.Background(), tc.resfiles, tc.pkg); !resourcesEqual(got, tc.want) {
			t.Errorf("ParseAll(%v, %v) = {%v}, want {%v}", tc.resfiles, tc.pkg, got, tc.want)
		}
	}
}

func TestParseAllContents(t *testing.T) {
	tests := []struct {
		resfiles []string
		pkg      string
		want     *rdpb.Resources
	}{
		{
			resfiles: createResfiles([]string{}),
			pkg:      "",
			want:     createResources("", []rdpb.Resource_Type{}, []string{}),
		},
		{
			resfiles: createResfiles([]string{"mini-1/res/values/strings.xml"}),
			pkg:      "example",
			want:     createResources("example", []rdpb.Resource_Type{rdpb.Resource_STRING}, []string{"greeting"}),
		},
		{
			resfiles: createResfiles([]string{"mini-2/res/xml/foo.xml"}),
			pkg:      "com.example",
			want:     createResources("com.example", []rdpb.Resource_Type{rdpb.Resource_XML, rdpb.Resource_ID}, []string{"foo", "foobar"}),
		},
		{
			resfiles: createResfiles([]string{"res/drawable-ldpi/foo.9.png", "res/menu/simple.xml"}),
			pkg:      "com.example",
			want: createResources("com.example",
				[]rdpb.Resource_Type{rdpb.Resource_DRAWABLE, rdpb.Resource_MENU, rdpb.Resource_ID, rdpb.Resource_ID},
				[]string{"foo", "simple", "item1", "item2"}),
		},
	}

	for _, tc := range tests {
		allContents := getAllContents(t, tc.resfiles)
		got, err := ParseAllContents(context.Background(), tc.resfiles, allContents, tc.pkg)
		if err != nil {
			t.Errorf("ParseAllContents(%v, %v) failed with error %v", tc.resfiles, tc.pkg, err)
		}
		if !resourcesEqual(got, tc.want) {
			t.Errorf("ParseAllContents(%v, %v) = {%v}, want {%v}", tc.resfiles, tc.pkg, got, tc.want)
		}
	}
}

// createResFile creates filename with the testdata as the base
func createResFile(filename string) string {
	fullPath := testdata + filename
	resFilePath, err := runfilelocation.Find(fullPath)
	if err != nil {
		log.Fatalf("Could not find the runfile at %v", resFilePath)
	}
	return resFilePath
}

// createResfiles creates filenames with the testdata as the base
func createResfiles(filenames []string) []string {
	var resfiles []string
	for _, filename := range filenames {
		resfiles = append(resfiles, createResFile(filename))
	}
	return resfiles
}

func getAllContents(t *testing.T, paths []string) [][]byte {
	var allContents [][]byte
	for _, path := range paths {
		contents, err := os.ReadFile(path)
		if err != nil {
			t.Errorf("cannot read file %v: %v", path, err)
		}
		allContents = append(allContents, contents)
	}
	return allContents
}

// createResources creates rdpb.Resources with package name pkg and resources {names[i], resource[i]}
func createResources(pkg string, resources []rdpb.Resource_Type, names []string) *rdpb.Resources {
	rscs := &rdpb.Resources{
		Pkg: pkg,
	}
	for i := 0; i < len(names); i++ {
		r := &rdpb.Resource{Name: names[i], ResourceType: resources[i]}
		rscs.Resource = append(rscs.Resource, r)
	}
	return rscs
}

// resourcesEqual checks if the two resources have the same package names and resources
func resourcesEqual(rscs1 *rdpb.Resources, rscs2 *rdpb.Resources) bool {
	return rscs1.Pkg == rscs2.Pkg && cmp.Equal(createResourcesMap(rscs1), createResourcesMap(rscs2))
}

// createResourcesMap creates a map of resources contained in rscs that maps the rdpb.Resource_Type to the names and the number of times the name appears.
func createResourcesMap(rscs *rdpb.Resources) map[rdpb.Resource_Type]map[string]int {
	m := make(map[rdpb.Resource_Type]map[string]int)
	for _, r := range rscs.Resource {
		if _, ok := m[r.GetResourceType()]; !ok {
			m[r.GetResourceType()] = make(map[string]int)
			m[r.GetResourceType()][r.GetName()] = 1
		} else if _, ok := m[r.GetResourceType()][r.GetName()]; !ok {
			m[r.GetResourceType()][r.GetName()] = 1
		} else {
			m[r.GetResourceType()][r.GetName()]++
		}
	}
	return m
}
