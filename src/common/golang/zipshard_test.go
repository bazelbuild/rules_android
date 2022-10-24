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

package shard

import (
	"archive/zip"
	"bytes"
	"errors"
	"fmt"
	"reflect"
	"sort"
	"strings"
	"testing"
)

func TestSepSharder(t *testing.T) {
	tcs := []struct {
		name     string
		sep      string
		wantName string
	}{
		{
			name:     "Hello",
			sep:      "/",
			wantName: "Hello",
		},
		{
			name:     "foo/bar/baz",
			sep:      "/",
			wantName: "foo/bar",
		},
		{
			name:     "com@google@Foo.dex",
			sep:      "@",
			wantName: "com@google",
		},
	}

	for _, tc := range tcs {
		checkShard := func(name string, sc int) int {
			if name != tc.wantName {
				t.Errorf("makeSepSharder(%s).Shard(%s, 1): got name: %s wanted: %s", tc.sep, tc.name, name, tc.wantName)
			}
			return 0
		}

		s := MakeSepFunc(tc.sep, Func(checkShard))
		s(tc.name, 1)
	}

}

func TestBadSharder(t *testing.T) {
	srcZip, err := makeZip(map[string]string{"hello": "world"})
	if err != nil {
		t.Fatalf("Could not make initial zip: %v", err)
	}

	for _, shardVal := range []int{-1, -244, 123} {
		zr, err := zip.NewReader(bytes.NewReader(srcZip), int64(len(srcZip)))
		if err != nil {
			t.Fatalf("could not read initial zip: %v", err)
		}
		zws := []*zip.Writer{zip.NewWriter(&bytes.Buffer{})}

		s := Func(func(name string, sc int) int {
			return shardVal
		})
		err = ZipShard(zr, zws, s)
		if err == nil || !strings.Contains(err.Error(), "invalid shard index") {
			t.Errorf("Returning shard value: %d gave: %v wanted an error with invalid shard index", shardVal, err)
		}
	}
}

func TestZipShard(t *testing.T) {
	tcs := []struct {
		name        string
		contents    map[string]string
		shardCount  int
		want        map[int][]string
		zipShardErr error
	}{
		{
			name: "Vanilla",
			contents: map[string]string{
				"foo/hello":        "world",
				"bar/something":    "stuff",
				"blah/nothing":     "here",
				"blah/everything":  "nowhere",
				"hello/everything": "nowhere",
			},
			shardCount: 5,
			want: map[int][]string{
				0: {"hello/everything"},
				3: {"foo/hello", "bar/something"},
				4: {"blah/nothing", "blah/everything"},
			},
		},
		{
			name:        "no output shards",
			contents:    map[string]string{"something": "something"},
			shardCount:  0,
			zipShardErr: errors.New("no output writers"),
		},
		{
			name:       "empty input zip",
			contents:   map[string]string{},
			shardCount: 5,
			want:       map[int][]string{},
		},
	}

	for _, tc := range tcs {
		srcZip, err := makeZip(tc.contents)
		if err != nil {
			t.Errorf("%s: could not create initial zip: %v", tc.name, err)
		}
		zr, err := zip.NewReader(bytes.NewReader(srcZip), int64(len(srcZip)))

		if err != nil {
			t.Errorf("%s: could not read initial zip: %v", tc.name, err)
			continue
		}
		bufs := make([]*bytes.Buffer, tc.shardCount)
		zws := make([]*zip.Writer, tc.shardCount)
		for i := range zws {
			bufs[i] = new(bytes.Buffer)
			zws[i] = zip.NewWriter(bufs[i])
		}
		s := MakeSepFunc("/", Func(func(name string, sc int) int {
			return len(name) % sc
		}))
		err = ZipShard(zr, zws, s)
		if !reflect.DeepEqual(err, tc.zipShardErr) {
			t.Errorf("%s: got zipshard error: %v wanted: %v", tc.name, err, tc.zipShardErr)
			continue
		}
		for i, s := range bufs {
			if err := zws[i].Close(); err != nil {
				t.Errorf("%s: shard: %d cannot close zip writer: %v", tc.name, tc.shardCount, err)
				continue
			}
			z, err := zip.NewReader(bytes.NewReader(s.Bytes()), int64(s.Len()))
			if err != nil {
				t.Errorf("%s: shard: %d cannot create zip reader: %v", tc.name, tc.shardCount, err)
				continue
			}
			var fileNames []string
			for _, f := range z.File {
				fileNames = append(fileNames, f.Name)
			}
			sort.Strings(fileNames)
			want, _ := tc.want[i]
			sort.Strings(want)
			if !reflect.DeepEqual(want, fileNames) {
				t.Errorf("%s: shard: %d got: %s wanted: %s", tc.name, i, fileNames, want)
			}
		}
	}
}

func makeZip(contents map[string]string) ([]byte, error) {
	var zin bytes.Buffer
	zw := zip.NewWriter(&zin)
	for name, body := range contents {
		f, err := zw.Create(name)
		if err != nil {
			return nil, fmt.Errorf("%s: could not create: %v", name, err)
		}
		_, err = f.Write([]byte(body))
		if err != nil {
			return nil, fmt.Errorf("%s: could not write: %s due to %v: ", name, body, err)
		}

	}
	if err := zw.Close(); err != nil {
		return nil, err
	}
	return zin.Bytes(), nil
}
