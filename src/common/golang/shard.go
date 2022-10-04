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

// Package shard provides functions to help sharding your data.
package shard

import (
	"archive/zip"
	"errors"
	"fmt"
	"hash/fnv"
	"io"
	"strings"
)

// Func converts a name and a number of shards into a particular shard index.
type Func func(name string, shardCount int) int

// FNV uses the FNV hash algo on the provided string and mods its result by shardCount.
func FNV(name string, shardCount int) int {
	h := fnv.New32()
	h.Write([]byte(name))
	return int(h.Sum32()) % shardCount
}

// MakeSepFunc creates a shard function that takes a substring from 0 to the last occurrence of
// separator from the name to be sharded, and passes that onto the provided shard function.
func MakeSepFunc(sep string, s Func) Func {
	return func(name string, shardCount int) int {
		idx := strings.LastIndex(name, sep)
		if idx == -1 {
			return s(name, shardCount)
		}
		return s(name[:idx], shardCount)
	}
}

// ZipShard takes a given zip reader, and shards its content across the provided io.Writers
// utilizing the provided SharderFunc.
func ZipShard(r *zip.Reader, zws []*zip.Writer, fn Func) error {
	sc := len(zws)
	if sc == 0 {
		return errors.New("no output writers")
	}

	for _, f := range r.File {
		if !f.Mode().IsRegular() {
			continue
		}
		si := fn(f.Name, sc)
		if si < 0 || si > sc {
			return fmt.Errorf("s.Shard(%s, %d) yields invalid shard index: %d", f.Name, sc, si)
		}
		zw := zws[si]
		var rc io.ReadCloser
		rc, err := f.Open()
		if err != nil {
			return fmt.Errorf("%s: could not open: %v", f.Name, err)
		}
		var zo io.Writer
		zo, err = zw.CreateHeader(&zip.FileHeader{
			Name:   f.Name,
			Method: zip.Store,
		})
		if err != nil {
			return fmt.Errorf("%s: could not create output entry: %v", f.Name, err)
		}
		if err := copyAndClose(zo, rc); err != nil {
			return fmt.Errorf("%s: copy to output failed: %v", f.Name, err)
		}
	}
	return nil
}

func copyAndClose(w io.Writer, rc io.ReadCloser) error {
	defer rc.Close()
	_, err := io.Copy(w, rc)
	return err
}
