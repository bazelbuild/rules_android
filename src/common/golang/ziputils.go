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

// Package ziputils provides utility functions to work with zip files.
package ziputils

import (
	"archive/zip"
	"bytes"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"time"

	"golang.org/x/sync/errgroup"
)

// Empty file contains only the End of central directory record. 0x06054b50
// https://en.wikipedia.org/wiki/Zip_(file_format)
var (
	emptyzip             = append([]byte{0x50, 0x4b, 0x05, 0x06}, make([]byte, 18)...)
	dirPerm  os.FileMode = 0755
)

// EmptyZipReader wraps an reader whose contents are the empty zip.
type EmptyZipReader struct {
	*bytes.Reader
}

// NewEmptyZipReader creates and returns an EmptyZipReader struct.
func NewEmptyZipReader() *EmptyZipReader {
	return &EmptyZipReader{bytes.NewReader(emptyzip)}
}

// EmptyZip creates empty zip archive.
func EmptyZip(dst string) error {
	zipfile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer zipfile.Close()
	_, err = io.Copy(zipfile, NewEmptyZipReader())
	return err
}

// Zip archives src into dst without compression.
func Zip(src, dst string) error {
	fi, err := os.Stat(src)
	if err != nil {
		return err
	}

	zipfile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer zipfile.Close()

	archive := zip.NewWriter(zipfile)
	defer archive.Close()

	if !fi.Mode().IsDir() {
		return WriteFile(archive, src, filepath.Base(src))
	}

	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			return nil
		}

		return WriteFile(archive, path, strings.TrimPrefix(path, src+string(filepath.Separator)))
	})
}

// WriteFile writes filename to the out zip writer.
func WriteFile(out *zip.Writer, filename, zipFilename string) error {
	// It's important to set timestamps to zero, otherwise we would break caching for unchanged files
	f, err := out.CreateHeader(&zip.FileHeader{Name: zipFilename, Method: zip.Store, Modified: time.Unix(0, 0)})
	if err != nil {
		return err
	}
	contents, err := ioutil.ReadFile(filename)
	if err != nil {
		return err
	}
	_, err = f.Write(contents)
	return err
}

// WriteReader writes a reader to the out zip writer.
func WriteReader(out *zip.Writer, in io.Reader, filename string) error {
	// It's important to set timestamps to zero, otherwise we would break caching for unchanged files
	f, err := out.CreateHeader(&zip.FileHeader{Name: filename, Method: zip.Store, Modified: time.Unix(0, 0)})
	if err != nil {
		return err
	}
	contents, err := ioutil.ReadAll(in)
	if err != nil {
		return err
	}
	_, err = f.Write(contents)
	return err
}

// Unzip expands srcZip in dst directory
func Unzip(srcZip, dst string) error {
	reader, err := zip.OpenReader(srcZip)
	if err != nil {
		return err
	}
	defer reader.Close()

	_, err = os.Stat(dst)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	if os.IsNotExist(err) {
		if err := os.MkdirAll(dst, dirPerm); err != nil {
			return err
		}
	}

	for _, file := range reader.File {
		path := filepath.Join(dst, file.Name)

		if file.FileInfo().IsDir() {
			if err := os.MkdirAll(path, dirPerm); err != nil {
				return err
			}
			continue
		}

		dir := filepath.Dir(path)
		_, err := os.Stat(dir)
		if err != nil && !os.IsNotExist(err) {
			return err
		}
		if os.IsNotExist(err) {
			if err := os.MkdirAll(dir, dirPerm); err != nil {
				return err
			}
		}

		if err := write(file, path); err != nil {
			return err
		}
	}

	return nil
}

// UnzipParallel expands zip archives in parallel.
// TODO(b/137549283) Update UnzipParallel and add test
func UnzipParallel(srcZipDestMap map[string]string) error {
	var eg errgroup.Group
	for z, d := range srcZipDestMap {
		zip, dest := z, d
		eg.Go(func() error { return Unzip(zip, dest) })
	}
	return eg.Wait()
}

func write(zf *zip.File, path string) error {
	rc, err := zf.Open()
	if err != nil {
		return err
	}
	defer rc.Close()
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = io.Copy(f, rc)
	return err
}
