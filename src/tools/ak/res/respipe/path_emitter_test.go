// Copyright 2022 The Bazel Authors. All rights reserved.
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

package respipe

import (
	"io/ioutil"
	"os"
	"path"
	"reflect"
	"sort"
	"testing"

	"context"
)

func TestEmitPathInfosDir(t *testing.T) {
	tmpDir, err := ioutil.TempDir("", "")
	if err != nil {
		t.Fatalf("%s: make failed: %v", tmpDir, err)
	}
	defer func() {
		if err := os.RemoveAll(tmpDir); err != nil {
			t.Errorf("%s: could not remove: %v", tmpDir, err)
		}
	}()

	touch := func(p string) string {
		if err := os.MkdirAll(path.Dir(path.Join(tmpDir, p)), 0744); err != nil {
			t.Fatalf("%s: mkdir failed: %v", p, err)
		}
		f, err := os.OpenFile(path.Join(tmpDir, p), os.O_CREATE|os.O_TRUNC, 0644)
		if err != nil {
			t.Fatalf("%s: touch failed: %v", p, err)
		}
		defer f.Close()
		return f.Name()
	}
	wantPaths := []string{
		"values/strings.xml",
		"values/styles.xml",
		"layout-land/hello.xml",
		"layout/hello.xml",
		"values-v19/styles.xml",
		"drawable-ldpi/foo.png",
		"raw/data.xml",
		"xml/perf.xml",
	}
	for i, p := range wantPaths {
		wantPaths[i] = touch(p)
	}
	touch("values/.placeholder")
	touch("something_random/data.txt")

	ctx, cxlFn := context.WithCancel(context.Background())
	defer cxlFn()
	piC, errC := EmitPathInfosDir(ctx, tmpDir)
	var gotPaths []string
Loop:
	for {
		select {
		case p, ok := <-piC:
			if !ok {
				break Loop
			}
			gotPaths = append(gotPaths, p.Path)
		case e, ok := <-errC:
			if !ok {
				break Loop
			}
			t.Fatalf("Unexpected failure: %v", e)

		}
	}
	sort.Strings(gotPaths)
	sort.Strings(wantPaths)
	if !reflect.DeepEqual(gotPaths, wantPaths) {
		t.Errorf("EmitPathInfosDir(): %v wanted: %v", gotPaths, wantPaths)
	}

}
