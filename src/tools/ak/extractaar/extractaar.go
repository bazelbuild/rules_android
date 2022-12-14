// Copyright 2021 The Bazel Authors. All rights reserved.
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

// Package extractaar extracts files from an aar.
package extractaar

import (
	"archive/zip"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"src/tools/ak/types"
)

// A tristate may be true, false, or unset
type tristate int

func (t tristate) isSet() bool {
	return t == tsTrue || t == tsFalse
}

func (t tristate) value() bool {
	return t == tsTrue
}

const (
	tsTrue  = 1
	tsFalse = -1

	manifest = iota
	res
	assets
)

var (
	// Cmd defines the command to run the extractor.
	Cmd = types.Command{
		Init: Init,
		Run:  Run,
		Desc: desc,
		Flags: []string{
			"aar", "label",
			"out_manifest", "out_res_dir", "out_assets_dir",
			"has_res", "has_assets",
		},
	}

	aar             string
	label           string
	outputManifest  string
	outputResDir    string
	outputAssetsDir string
	hasRes          int
	hasAssets       int

	initOnce sync.Once
)

// Init initializes the extractor.
func Init() {
	initOnce.Do(func() {
		flag.StringVar(&aar, "aar", "", "Path to the aar")
		flag.StringVar(&label, "label", "", "Target's label")
		flag.StringVar(&outputManifest, "out_manifest", "", "Output manifest")
		flag.StringVar(&outputResDir, "out_res_dir", "", "Output resources directory")
		flag.StringVar(&outputAssetsDir, "out_assets_dir", "", "Output assets directory")
		flag.IntVar(&hasRes, "has_res", 0, "Whether the aar has resources")
		flag.IntVar(&hasAssets, "has_assets", 0, "Whether the aar has assets")
	})
}

func desc() string {
	return "Extracts files from an AAR"
}

type aarFile struct {
	path    string
	relPath string
}

func (file *aarFile) String() string {
	return fmt.Sprintf("%s:%s", file.path, file.relPath)
}

type toCopy struct {
	src  string
	dest string
}

// Run runs the extractor
func Run() {
	if err := doWork(aar, label, outputManifest, outputResDir, outputAssetsDir, hasRes, hasAssets); err != nil {
		log.Fatal(err)
	}
}

func doWork(aar, label, outputManifest, outputResDir, outputAssetsDir string, hasRes, hasAssets int) error {
	tmpDir, err := os.MkdirTemp("", "extractaar_")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)

	files, err := extractAAR(aar, tmpDir)
	if err != nil {
		return err
	}

	validators := map[int]validator{
		manifest: manifestValidator{dest: outputManifest},
		res:      resourceValidator{dest: outputResDir, hasRes: tristate(hasRes), ruleAttr: "has_res"},
		assets:   resourceValidator{dest: outputAssetsDir, hasRes: tristate(hasAssets), ruleAttr: "has_assets"},
	}

	var filesToCopy []*toCopy
	var validationErrs []*BuildozerError
	for fileType, files := range groupAARFiles(files) {
		validatedFiles, err := validators[fileType].validate(files)
		if err != nil {
			validationErrs = append(validationErrs, err)
			continue
		}
		filesToCopy = append(filesToCopy, validatedFiles...)
	}

	if len(validationErrs) != 0 {
		return errors.New(mergeBuildozerErrors(label, validationErrs))
	}

	for _, file := range filesToCopy {
		if err := copyFile(file.src, file.dest); err != nil {
			return err
		}
	}

	// TODO(ostonge): Add has_res/has_assets attr to avoid having to do this
	// We need to create at least one file so that Bazel does not complain
	// that the output tree artifact was not created.
	if err := createIfEmpty(outputResDir, "res/values/empty.xml", "<resources/>"); err != nil {
		return err
	}
	// aapt will ignore this file and not print an error message, because it
	// thinks that it is a swap file
	if err := createIfEmpty(outputAssetsDir, "assets/empty_asset_generated_by_bazel~", ""); err != nil {
		return err
	}
	return nil
}

func groupAARFiles(aarFiles []*aarFile) map[int][]*aarFile {
	// Map of file type to channel of aarFile
	filesMap := make(map[int][]*aarFile)
	for _, fileType := range []int{manifest, res, assets} {
		filesMap[fileType] = make([]*aarFile, 0)
	}

	for _, file := range aarFiles {
		if file.relPath == "AndroidManifest.xml" {
			filesMap[manifest] = append(filesMap[manifest], file)
		} else if strings.HasPrefix(file.relPath, "res"+string(os.PathSeparator)) {
			filesMap[res] = append(filesMap[res], file)
		} else if strings.HasPrefix(file.relPath, "assets"+string(os.PathSeparator)) {
			filesMap[assets] = append(filesMap[assets], file)
		}
		// TODO(ostonge): support jar and aidl files
	}
	return filesMap
}

func extractAAR(aar string, dest string) ([]*aarFile, error) {
	reader, err := zip.OpenReader(aar)
	if err != nil {
		return nil, err
	}
	defer reader.Close()

	var files []*aarFile
	for _, f := range reader.File {
		if f.FileInfo().IsDir() {
			continue
		}
		extractedPath := filepath.Join(dest, f.Name)
		if err := extractFile(f, extractedPath); err != nil {
			return nil, err
		}
		files = append(files, &aarFile{path: extractedPath, relPath: f.Name})
	}
	return files, nil
}

func extractFile(file *zip.File, dest string) error {
	if err := os.MkdirAll(filepath.Dir(dest), os.ModePerm); err != nil {
		return err
	}
	outFile, err := os.OpenFile(dest, os.O_WRONLY|os.O_CREATE, file.Mode())
	if err != nil {
		return err
	}
	defer outFile.Close()

	rc, err := file.Open()
	if err != nil {
		return err
	}
	defer rc.Close()

	_, err = io.Copy(outFile, rc)
	if err != nil {
		return err
	}
	return nil
}

func copyFile(name, dest string) error {
	in, err := os.Open(name)
	if err != nil {
		return err
	}
	defer in.Close()

	if err := os.MkdirAll(filepath.Dir(dest), os.ModePerm); err != nil {
		return err
	}
	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	if err != nil {
		return err
	}
	return nil
}

func dirIsEmpty(dir string) (bool, error) {
	f, err := os.Open(dir)
	if os.IsNotExist(err) {
		return true, nil
	}
	if err != nil {
		return false, err
	}
	defer f.Close()

	_, err = f.Readdirnames(1)
	if err == io.EOF {
		return true, nil
	}
	return false, err
}

// Create the file with the content if the directory is empty or does not exists
func createIfEmpty(dir, filename, content string) error {
	isEmpty, err := dirIsEmpty(dir)
	if err != nil {
		return err
	}
	if isEmpty {
		dest := filepath.Join(dir, filename)
		if err := os.MkdirAll(filepath.Dir(dest), os.ModePerm); err != nil {
			return err
		}
		return os.WriteFile(dest, []byte(content), 0644)
	}
	return nil
}
