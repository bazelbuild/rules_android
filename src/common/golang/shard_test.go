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
	"testing"
)

func TestFNV(t *testing.T) {
	tests := []struct {
		name string
		in   []string
		sc   int
		want []int
	}{
		{
			name: "shardCount2",
			in:   []string{"foo", "bar", "baz"},
			sc:   2,
			want: []int{1, 0, 0},
		},
		{
			name: "shardCount5",
			in:   []string{"foo", "bar", "baz"},
			sc:   5,
			want: []int{0, 2, 0},
		},
		{
			name: "shardCount9",
			in:   []string{"foo", "bar", "baz"},
			sc:   9,
			want: []int{2, 7, 6},
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			for idx, in := range test.in {
				if shard := FNV(in, test.sc); shard != test.want[idx] {
					t.Errorf("FNV applied for: %q got: %v wanted: %v", in, shard, test.want[idx])
				}
			}
		})
	}
}

func TestMakeSepFunc(t *testing.T) {
	tests := []struct {
		name string
		sep  string
		in   []string
		sc   int
		want []int
	}{
		{
			name: "makeSepFunc",
			sep:  "@",
			in:   []string{"foo@postfix", "bar@postfix", "baz@postfix"},
			sc:   9,
			want: []int{2, 7, 6},
		},
		{
			name: "makeSepFuncWithNoSep",
			sep:  "",
			in:   []string{"foo", "bar", "baz"},
			sc:   9,
			want: []int{2, 7, 6},
		},
		{
			name: "makeSepFuncWithWrongSep",
			sep:  "*",
			in:   []string{"foo", "bar", "baz"},
			sc:   9,
			want: []int{2, 7, 6},
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			for idx, in := range test.in {
				shardFn := MakeSepFunc(test.sep, FNV)
				if shard := shardFn(in, test.sc); shard != test.want[idx] {
					t.Errorf("MakeSepFunc applied for: %q got: %v wanted: %v", in, shard, test.want[idx])
				}
			}
		})
	}
}
