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

// Package patch sets/replaces the application class/package in a given AndroidManifest.xml.
package patch

import (
	"bytes"
	"encoding/xml"
	"flag"
	"io/ioutil"
	"log"
	"os"
	"strings"
	"sync"

	"src/common/golang/flags"
	"src/tools/ak/manifestutils"
	"src/tools/ak/types"
)

var stubManifest = `<?xml version="1.0" encoding="utf-8"?>
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android">
  <application/>
</manifest>`

var (
	// Cmd defines the command to run patch
	Cmd = types.Command{
		Init:  Init,
		Run:   Run,
		Desc:  desc,
		Flags: []string{"in", "out", "attr", "app", "oldapp", "pkg"},
	}

	// Variables that hold flag values
	split  flags.StringList
	attr   flags.StringList
	in     string
	out    string
	app    string
	oldApp string
	pkg    string

	initOnce sync.Once
)

// Init initializes patch.
func Init() {
	initOnce.Do(func() {
		flag.StringVar(&in, "in", "", "Path to the input xml file.")
		flag.StringVar(&out, "out", "", "Path to the output xml file.")
		flag.Var(&attr, "attr", "(optional) attr(s) to set. {element}:{attr}:{value}.")
		flag.Var(&split, "split", "(optional) splits(s) to write. {name}:{file}.")
		flag.StringVar(&oldApp, "oldapp", "", "(optional) Path to output the old application class name.")
		flag.StringVar(&pkg, "pkg", "", "(optional) Path to output the package name.")
	})
}

func desc() string {
	return "Setapp sets/replaces the application class in a given AndroidManifest.xml."
}

// Run is the entry point for patch.
func Run() {
	if in == "" || (out == "" && split == nil) {
		log.Fatal("fields and -in and -out|-splits and must be defined.")
	}

	elems := manifestutils.CreatePatchElements(attr)
	elems[manifestutils.ElemManifest] = make(map[string]xml.Attr)

	b, err := ioutil.ReadFile(in)
	if err != nil {
		log.Fatalf("ioutil.ReadFile(%q) failed: %v", in, err)
	}
	var manifest manifestutils.Manifest
	xml.Unmarshal(b, &manifest)

	// Optional parse package name and/or application class name before replacing
	if pkg != "" || oldApp != "" {

		if pkg != "" {
			err = ioutil.WriteFile(pkg, []byte(manifest.Package), 0644)
			if err != nil {
				log.Fatalf("ioutil.WriteFile(%q) failed: %v", pkg, err)
			}
		}
		if oldApp != "" {
			appName := manifest.Application.Name
			if appName == "" {
				appName = "android.app.Application"
			}
			err := ioutil.WriteFile(oldApp, []byte(appName), 0644)
			if err != nil {
				log.Fatalf("ioutil.WriteFile(%q) failed: %v", oldApp, err)
			}
		}
	}

	// parse manifest attrs if any for stub manifest
	if manifest.Package != "" {
		elems[manifestutils.ElemManifest][manifestutils.AttrPackage] = xml.Attr{
			Name: xml.Name{Local: manifestutils.AttrPackage}, Value: manifest.Package}
	}
	if manifest.SharedUserID != "" {
		elems[manifestutils.ElemManifest][manifestutils.AttrSharedUserID] = xml.Attr{
			Name:  xml.Name{Space: manifestutils.NameSpace, Local: manifestutils.AttrSharedUserID},
			Value: manifest.SharedUserID}
	}
	if manifest.SharedUserLabel != "" {
		elems[manifestutils.ElemManifest][manifestutils.AttrSharedUserLabel] = xml.Attr{
			Name:  xml.Name{Space: manifestutils.NameSpace, Local: manifestutils.AttrSharedUserLabel},
			Value: manifest.SharedUserLabel}
	}
	if manifest.VersionCode != "" {
		elems[manifestutils.ElemManifest][manifestutils.AttrVersionCode] = xml.Attr{
			Name:  xml.Name{Space: manifestutils.NameSpace, Local: manifestutils.AttrVersionCode},
			Value: manifest.VersionCode}
	}
	if manifest.VersionName != "" {
		elems[manifestutils.ElemManifest][manifestutils.AttrVersionName] = xml.Attr{
			Name:  xml.Name{Space: manifestutils.NameSpace, Local: manifestutils.AttrVersionName},
			Value: manifest.VersionName}
	}

	if out != "" {
		o, err := os.Create(out)
		if err != nil {
			log.Fatalf("Error creating output file %q:  %v", out, err)
		}
		defer o.Close()

		if err := manifestutils.WriteManifest(o, bytes.NewReader(b), elems); err != nil {
			log.Fatalf("Error setting fields: %v", err)
		}

	}

	// Patch the splits
	b = []byte(stubManifest)
	for _, s := range split {
		pts := strings.Split(s, ":")
		if len(pts) != 2 {
			log.Fatalf("Failed to parse split %s", s)
		}
		elems[manifestutils.ElemManifest][manifestutils.AttrSplit] = xml.Attr{
			Name: xml.Name{Local: manifestutils.AttrSplit}, Value: pts[0]}

		o, err := os.Create(pts[1])
		if err != nil {
			log.Fatalf("Error creating output file %q:  %v", pts[1], err)
		}

		if err := manifestutils.WriteManifest(o, bytes.NewReader(b), elems); err != nil {
			log.Fatalf("Error setting fields: %v", err)
		}
	}
}
