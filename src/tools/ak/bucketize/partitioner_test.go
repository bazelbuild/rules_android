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
	"io/ioutil"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"testing"

	"src/common/golang/shard"
	"src/tools/ak/res/res"
)

func TestInternalStorePathResource(t *testing.T) {
	// test internal storePathResource and skip the creation of real files.
	tcs := []struct {
		name       string
		inFiles    map[string]string
		partitions map[res.Type][]io.Writer
		shardFn    shard.Func
		want       map[res.Type][][]string
		wantErr    bool
	}{
		{
			name: "MultipleResTypeFilesWithShardsOfDifferentSizes",
			inFiles: map[string]string{
				"res/drawable/2-foo.xml":  "all",
				"res/layout/0-bar.xml":    "your",
				"res/color/0-baz.xml":     "base",
				"res/layout/1-qux.xml":    "are",
				"res/drawable/0-quux.xml": "belong",
				"res/color/0-corge.xml":   "to",
				"res/color/0-grault.xml":  "us",
				"res/layout/0-garply.xml": "!",
			},
			shardFn: shard.Func(func(fqn string, shardCount int) int {
				// sharding strategy is built into the file name as "<shard num>-foo.bar" (i.e. 8-baz.xml)
				name := strings.Split(fqn, "/")[1]
				ai := strings.SplitN(name, "-", 2)[0]
				shard, err := strconv.Atoi(ai)
				if err != nil {
					t.Fatalf("Atoi(%s) got err: %v", ai, err)
				}
				return shard
			}),
			partitions: map[res.Type][]io.Writer{
				res.Drawable: {&bytes.Buffer{}, &bytes.Buffer{}, &bytes.Buffer{}},
				res.Color:    {&bytes.Buffer{}},
				res.Layout:   {&bytes.Buffer{}, &bytes.Buffer{}},
			},
			want: map[res.Type][][]string{
				res.Drawable: {{"res/drawable/0-quux.xml"}, {}, {"res/drawable/2-foo.xml"}},
				res.Color:    {{"res/color/0-baz.xml", "res/color/0-corge.xml", "res/color/0-grault.xml"}},
				res.Layout:   {{"res/layout/0-bar.xml", "res/layout/0-garply.xml"}, {"res/layout/1-qux.xml"}},
			},
		},
		{
			name: "IgnoredFilePatterns",
			inFiles: map[string]string{
				"res/drawable/.ignore": "me",
			},
			shardFn:    shard.FNV,
			partitions: map[res.Type][]io.Writer{res.Drawable: {&bytes.Buffer{}}},
			wantErr:    true,
		},
		{
			name:       "NoFiles",
			inFiles:    map[string]string{},
			shardFn:    shard.FNV,
			partitions: map[res.Type][]io.Writer{res.Drawable: {&bytes.Buffer{}}},
			want:       map[res.Type][][]string{res.Drawable: {{}}},
		},
	}

	order := make(map[string]int)
	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			ps, err := makePartitionSession(tc.partitions, tc.shardFn, order)
			if err != nil {
				t.Errorf("MakePartitionSession(%v, %v, %d) got err: %v", tc.partitions, tc.shardFn, 0, err)
				return
			}

			for k, v := range tc.inFiles {
				pi, err := res.ParsePath(k)
				if err != nil {
					if !tc.wantErr {
						t.Fatalf("ParsePath(%s) got err: %v", k, err)
					}
					return
				}
				if err := ps.storePathResource(pi, strings.NewReader(v)); err != nil {
					t.Fatalf("storePathResource got unexpected err: %v", err)
				}
			}

			if err := ps.Close(); err != nil {
				t.Errorf("partition Close() got err: %v", err)
				return
			}

			// validate data outputted to the partitions
			got := make(map[res.Type][][]string)
			for rt, shards := range tc.partitions {
				shardPaths := make([][]string, 0, len(shards))
				for _, shard := range shards {
					br := bytes.NewReader(shard.(*bytes.Buffer).Bytes())
					rr, err := zip.NewReader(br, br.Size())
					if err != nil {
						t.Errorf("NewReader(%v, %d) got err: %v", br, br.Size(), err)
						return
					}
					paths := make([]string, 0, len(rr.File))
					for _, f := range rr.File {
						paths = append(paths, f.Name)
						c, err := readAll(f)
						if err != nil {
							t.Errorf("readAll got err: %v", err)
							return
						}
						if tc.inFiles[f.Name] != c {
							t.Errorf("error copying data for %s got %q but wanted %q", f.Name, c, tc.inFiles[f.Name])
							return
						}
					}
					sort.Strings(paths)
					shardPaths = append(shardPaths, paths)
				}
				got[rt] = shardPaths
			}
			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("DeepEqual(\n%#v\n,\n%#v\n): returned false", got, tc.want)
			}
		})
	}
}

func TestCollectValues(t *testing.T) {
	tcs := []struct {
		name       string
		pathVPsMap map[string]map[res.FullyQualifiedName][]byte
		pathRAMap  map[string][]xml.Attr
		partitions map[res.Type][]io.Writer
		want       map[res.Type][][]string
		wantErr    bool
	}{
		{
			name: "MultipleResTypesShardsResources",
			partitions: map[res.Type][]io.Writer{
				res.Attr:   {&bytes.Buffer{}, &bytes.Buffer{}},
				res.String: {&bytes.Buffer{}, &bytes.Buffer{}},
				res.Color:  {&bytes.Buffer{}, &bytes.Buffer{}},
			},
			pathVPsMap: map[string]map[res.FullyQualifiedName][]byte{
				"res/values/strings.xml": {
					res.FullyQualifiedName{Package: "res-auto", Type: res.String, Name: "foo"}: []byte("<string name='foo'>bar</string>"),
					res.FullyQualifiedName{Package: "android", Type: res.String, Name: "baz"}:  []byte("<string name='baz'>qux</string>"),
					res.FullyQualifiedName{Package: "res-auto", Type: res.Attr, Name: "quux"}:  []byte("<attr name='quux'>corge</attr>"),
				},
				"res/values/attr.xml": {
					res.FullyQualifiedName{Package: "android", Type: res.Attr, Name: "foo"}: []byte("<attr name='android:foo'>bar</attr>"),
				},
				"baz/res/values/attr.xml": {
					res.FullyQualifiedName{Package: "android", Type: res.Attr, Name: "bazfoo"}: []byte("<attr name='android:bazfoo'>qix</attr>"),
				},
				"baz/res/values/strings.xml": {
					res.FullyQualifiedName{Package: "android", Type: res.String, Name: "baz"}: []byte("<string name='baz'>qux</string>"),
				},
				"foo/res/values/attr.xml": {
					res.FullyQualifiedName{Package: "android", Type: res.Attr, Name: "foofoo"}: []byte("<attr name='android:foofoo'>qex</attr>"),
				},
				"foo/res/values/color.xml": {
					res.FullyQualifiedName{Package: "android", Type: res.Color, Name: "foobar"}: []byte("<color name='foobar'>#FFFFFFFF</color>"),
				},
				"dir/res/values/strings.xml": {
					res.FullyQualifiedName{Package: "android", Type: res.String, Name: "dirbaz"}: []byte("<string name='dirbaz'>qux</string>"),
				},
				"dir/res/values/color.xml": {
					res.FullyQualifiedName{Package: "android", Type: res.Color, Name: "dirfoobar"}: []byte("<color name='dirfoobar'>#FFFFFFFF</color>"),
				},
			},
			pathRAMap: map[string][]xml.Attr{
				"res/values/strings.xml": {
					xml.Attr{Name: xml.Name{Space: "xmlns", Local: "ns1"}, Value: "path1"},
					xml.Attr{Name: xml.Name{Space: "xmlns", Local: "ns2"}, Value: "path2"},
				},
			},
			want: map[res.Type][][]string{
				res.Attr: {
					{
						"res/values/strings.xml", "<?xml version='1.0' encoding='utf-8'?><resources xmlns:ns1=\"path1\" xmlns:ns2=\"path2\"><attr name='quux'>corge</attr></resources>",
					},
					{
						"res/values/strings.xml", "<?xml version='1.0' encoding='utf-8'?><resources xmlns:ns1=\"path1\" xmlns:ns2=\"path2\"></resources>",
					},
				},
				res.String: {
					{
						"res/values/strings.xml", "<?xml version='1.0' encoding='utf-8'?><resources xmlns:ns1=\"path1\" xmlns:ns2=\"path2\"><string name='baz'>qux</string><string name='foo'>bar</string></resources>",
						"res/values/strings.xml", "<?xml version='1.0' encoding='utf-8'?><resources><string name='dirbaz'>qux</string></resources>",
						"res/values/strings.xml", "<?xml version='1.0' encoding='utf-8'?><resources><string name='baz'>qux</string></resources>",
					},
					{
						"res/values/strings.xml", "<?xml version='1.0' encoding='utf-8'?><resources xmlns:ns1=\"path1\" xmlns:ns2=\"path2\"></resources>",
						"res/values/strings.xml", "<?xml version='1.0' encoding='utf-8'?><resources></resources>",
						"res/values/strings.xml", "<?xml version='1.0' encoding='utf-8'?><resources></resources>",
					},
				},
				res.Color: {
					{
						"res/values/color.xml", "<?xml version='1.0' encoding='utf-8'?><resources><color name='foobar'>#FFFFFFFF</color></resources>",
						"res/values/color.xml", "<?xml version='1.0' encoding='utf-8'?><resources><color name='dirfoobar'>#FFFFFFFF</color></resources>",
					},
					{
						"res/values/color.xml", "<?xml version='1.0' encoding='utf-8'?><resources></resources>",
						"res/values/color.xml", "<?xml version='1.0' encoding='utf-8'?><resources></resources>",
					},
				},
			},
		},
		{
			name: "NoValuesPayloads",
			pathVPsMap: map[string]map[res.FullyQualifiedName][]byte{
				"res/values/strings.xml": {},
			},
			partitions: map[res.Type][]io.Writer{res.String: {&bytes.Buffer{}}},
			want:       map[res.Type][][]string{res.String: {{}}},
		},
		{
			name: "ResTypeValuesResTypeMismatch",
			pathVPsMap: map[string]map[res.FullyQualifiedName][]byte{
				"res/values/strings.xml": {
					res.FullyQualifiedName{
						Package: "res-auto",
						Type:    res.String,
						Name:    "foo",
					}: []byte("<string name='foo'>bar</string>"),
				},
			},
			partitions: map[res.Type][]io.Writer{res.Attr: {&bytes.Buffer{}}},
			want:       map[res.Type][][]string{res.Attr: {{}}},
		},
	}

	shardFn := func(name string, shardCount int) int { return 0 }
	order := map[string]int{
		"foo/res/values/attr.xml":    0,
		"foo/res/values/color.xml":   1,
		"res/values/attr.xml":        2,
		"res/values/strings.xml":     3,
		"dir/res":                    4,
		"baz/res/values/attr.xml":    5,
		"baz/res/values/strings.xml": 6,
	}
	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			ps, err := makePartitionSession(tc.partitions, shardFn, order)
			if err != nil {
				t.Errorf("makePartitionSession(%v, %v, %d) got err: %v", tc.partitions, shard.FNV, 0, err)
				return
			}
			for p, vps := range tc.pathVPsMap {
				pi, err := res.ParsePath(p)
				if err != nil {
					t.Errorf("ParsePath(%s) got err: %v", p, err)
					return
				}
				for fqn, p := range vps {
					ps.CollectValues(&res.ValuesResource{Src: &pi, N: fqn, Payload: p})
				}
			}
			for p, as := range tc.pathRAMap {
				pi, err := res.ParsePath(p)
				if err != nil {
					t.Errorf("ParsePath(%s) got err: %v", p, err)
					return
				}
				for _, a := range as {
					ps.CollectResourcesAttribute(&ResourcesAttribute{ResFile: &pi, Attribute: a})
				}
			}
			if err := ps.Close(); err != nil {
				t.Errorf("partition Close() got err: %v", err)
				return
			}

			// validate data outputted to the partitions.
			got := make(map[res.Type][][]string)
			for rt, shards := range tc.partitions {
				shardPaths := make([][]string, 0, len(shards))
				for _, shard := range shards {
					br := bytes.NewReader(shard.(*bytes.Buffer).Bytes())
					rr, err := zip.NewReader(br, br.Size())
					if err != nil {
						t.Errorf("NewReader(%v, %d) got err: %v", br, br.Size(), err)
						return
					}
					paths := make([]string, 0, len(rr.File))
					for _, f := range rr.File {
						c, err := readAll(f)
						if err != nil {
							t.Errorf("readAll got err: %v", err)
							return
						}
						paths = append(paths, f.Name, c)
					}
					shardPaths = append(shardPaths, paths)
				}
				got[rt] = shardPaths
			}
			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("DeepEqual(\n%#v\n,\n%#v\n): returned false", got, tc.want)
			}
		})
	}
}

func readAll(f *zip.File) (string, error) {
	rc, err := f.Open()
	if err != nil {
		return "", fmt.Errorf("%q: Open got err: %v", f.Name, err)
	}
	defer rc.Close()
	body, err := ioutil.ReadAll(rc)
	if err != nil {
		return "", fmt.Errorf("%q: ReadAll got err: %v", f.Name, err)
	}
	return string(body), nil
}
