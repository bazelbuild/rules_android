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
package ini

import (
	"bytes"
	"reflect"
	"strings"
	"testing"
)

func TestParseFunc(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want map[string]string
	}{
		{
			name: "ini_single_line",
			in:   "test=abc",
			want: map[string]string{"test": "abc"},
		},
		{
			name: "ini_multi_line",
			in: `key=data
key2=more data`,
			want: map[string]string{"key": "data", "key2": "more data"},
		},
		{
			name: "ini_with_comment",
			in: `key=data
;key2=irrelevant data
#key3=more irrelevant data`,
			want: map[string]string{"key": "data"},
		},
		{
			name: "ini_with_whitespace",
			in: `key = data
another_key = The data
yet_another_key	=	more data`,
			want: map[string]string{"key": "data", "another_key": "The data", "yet_another_key": "more data"},
		},
		{
			name: "ini_with_empty_data",
			in: `key=data
key2=
key3=more data`,
			want: map[string]string{"key": "data", "key2": "", "key3": "more data"},
		},
		{
			name: "invalid_ini",
			in: `key=data
invalid line
key2=The data`,
			want: map[string]string{"key": "data", "key2": "The data"},
		},
		{
			name: "ini_with_duplicate",
			in: `key=data
key=duplicate`,
			want: map[string]string{"key": "duplicate"},
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			iniOut := parse(test.in)
			if eq := reflect.DeepEqual(iniOut, test.want); !eq {
				t.Errorf("Parsing ini failed for: %q got: %v wanted: %v", test.in, iniOut, test.want)
			}
		})
	}
}

func TestWriteFunc(t *testing.T) {
	tests := []struct {
		name string
		in   map[string]string
		want string
	}{
		{
			name: "ini_single_line",
			in:   map[string]string{"test": "abc"},
			want: "test=abc\n",
		},
		{
			name: "ini_multi_line",
			in:   map[string]string{"key": "data", "key2": "more data"},
			want: `key=data
key2=more data
`,
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			b := new(bytes.Buffer)
			write(b, test.in)
			if strings.Compare(b.String(), test.want) != 0 {
				t.Errorf("Writing ini failed for: %q got: %v wanted: %v", test.in, b.String(), test.want)
			}
		})
	}
}
