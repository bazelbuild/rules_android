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

package compile

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"testing"
)

func TestDirReplacer(t *testing.T) {

	qualified := []string{
		"res/values-en-rGB/strings.xml",
		"res/values-es-rMX/strings.xml",
		"res/values-sr-rLatn/strings.xml",
		"res/values-sr-rLatn-xhdpi/strings.xml",
		"res/values-es-419/strings.xml",
		"res/values-es-419-xhdpi/strings.xml"}

	expected := []string{
		"res/values-en-rGB/strings.xml",
		"res/values-es-rMX/strings.xml",
		"res/values-b+sr+Latn/strings.xml",
		"res/values-b+sr+Latn-xhdpi/strings.xml",
		"res/values-b+es+419/strings.xml",
		"res/values-b+es+419-xhdpi/strings.xml"}

	var actual []string
	for _, d := range qualified {
		actual = append(actual, dirReplacer.Replace(d))
	}

	if !reflect.DeepEqual(expected, actual) {
		t.Errorf("dirReplacer.Replace(%v) = %v want %v", qualified, actual, expected)
	}
}

func TestSanitizeDirs(t *testing.T) {
	base, err := ioutil.TempDir("", "res-")
	dirs := []string{
		"values",
		"values-bas-foo",
		"values-foo-rNOTGOOD",
		"values-foo-rNOBUENO-baz",
	}
	for _, dir := range dirs {
		if err := os.Mkdir(filepath.Join(base, dir), 0777); err != nil {
			t.Fatal(err)
		}
	}

	var expected sort.StringSlice
	expected = append(expected, []string{
		"values",
		"values-bas-foo",
		"values-foo-rVERY-GOOD",
		"values-foo-rMUCHO-BUENO-baz"}...)

	r := strings.NewReplacer("NOTGOOD", "VERY-GOOD", "NOBUENO", "MUCHO-BUENO")
	if err := sanitizeDirs(base, r); err != nil {
		t.Fatalf("sanitizeDirs(%s, %v) failed %v", base, r, err)
	}

	src, err := os.Open(base)
	if err != nil {
		t.Fatal(err)
	}
	defer src.Close()

	fs, err := src.Readdir(-1)
	if err != nil {
		t.Fatal(err)
	}

	actual := make(map[string]bool)
	for _, f := range fs {
		actual[f.Name()] = true
	}

	for _, dir := range dirs {
		expected := r.Replace(dir)
		if expected != dir && actual[dir] {
			t.Errorf("sanitizeDirs(%s) = %v got invalid dir %s. Expected %s ", base, actual, dir, expected)
		}
		if _, ok := actual[expected]; !ok {
			t.Errorf("sanitizeDirs(%s) = %v missing dir %s", base, actual, expected)
		}
	}

}
