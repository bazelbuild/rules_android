// Copyright 2024 The Bazel Authors. All rights reserved.
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

// split_core_jar splits the given jar into a 'core' jar containing packages found in  --core_jars,
// and an 'auxiliary' jar containing the remaining packages
package main

import (
	"archive/zip"
	"io"
	"os"
	"strings"
	"time"

  "flag"
  "log"
  "bitbucket.org/creachadair/stringset"
)

var (
	inputPath              = flag.String("input", "", "input jar path")
	coreJarPathsStr           = flag.String("core_jars", "", "input core jar paths, to filter against")
	outputCoreJarPath      = flag.String("output_core_jar", "", "output core jar path")
	outputAuxiliaryJarPath = flag.String("output_auxiliary_jar", "", "output auxiliary jar path")
	exclusionsStr             = flag.String("exclusions", "", "packages to skip in core jar")

	martinEpoch = parseTimeOrDie(time.RFC3339, "2010-01-01T00:00:00Z")
)

func parseTimeOrDie(layout, value string) time.Time {
	t, err := time.Parse(layout, value)
	if err != nil {
		panic(err)
	}
	return t
}

type outputZip struct {
	f *os.File
	w *zip.Writer
}

func createOutputZip(p string) (*outputZip, error) {
	z := &outputZip{}
	var err error
	z.f, err = os.Create(p)
	if err != nil {
		return nil, err
	}
	z.w = zip.NewWriter(z.f)
	return z, nil
}

func (z *outputZip) Close() error {
	err := z.w.Close()
	if err != nil {
		return err
	}
	err = z.f.Close()
	if err != nil {
		return err
	}
	return nil
}

func (z *outputZip) Copy(f *zip.File) error {
	w, err := z.w.CreateHeader(&zip.FileHeader{Name: f.Name, Modified: martinEpoch})
	if err != nil {
		return err
	}
	r, err := f.Open()
	if err != nil {
		return err
	}
	defer r.Close()
	_, err = io.Copy(w, r)
	if err != nil {
		return err
	}
	return nil
}

func portableInit() {
  flag.Parse()
}

func main() {
  portableInit()

	packages := stringset.New()
  coreJarPathsArr := strings.Split(*coreJarPathsStr, ",")
  coreJarPaths := &coreJarPathsArr
  exclusionsArr := strings.Split(*exclusionsStr, ",")
  exclusions := &exclusionsArr

	for _, coreJar := range *coreJarPaths {
		r, err := zip.OpenReader(coreJar)
		if err != nil {
			log.Fatal(err)
		}
		defer r.Close()
		for _, f := range r.File {
			if !strings.HasSuffix(f.Name, ".class") {
				continue
			}
			idx := strings.LastIndex(f.Name, "/")
			if idx == -1 {
				continue
			}
			packages.Add(f.Name[:idx])
		}
	}

	packages.Discard(*exclusions...)

	reader, err := zip.OpenReader(*inputPath)
	if err != nil {
		log.Fatal(err)
	}
	coreJar, err := createOutputZip(*outputCoreJarPath)
	if err != nil {
		log.Fatal(err)
	}
	outputAuxiliaryJarPath, err := createOutputZip(*outputAuxiliaryJarPath)
	if err != nil {
		log.Fatal(err)
	}
	for _, f := range reader.File {
		if !strings.HasSuffix(f.Name, ".class") {
			continue
		}
		idx := strings.LastIndex(f.Name, "/")
		if idx == -1 {
			continue
		}
		if packages.Contains(f.Name[:idx]) {
			err := coreJar.Copy(f)
			if err != nil {
				log.Fatal(err)
			}
		} else {
			err := outputAuxiliaryJarPath.Copy(f)
			if err != nil {
				log.Fatal(err)
			}
		}
	}
	if err = coreJar.Close(); err != nil {
		log.Fatal(err)
	}
	if err = outputAuxiliaryJarPath.Close(); err != nil {
		log.Fatal(err)
	}
	if err = reader.Close(); err != nil {
		log.Fatal(err)
	}
}
