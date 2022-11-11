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
	"errors"
	"reflect"
	"testing"

	"context"
)

func TestPrefixErr(t *testing.T) {
	tests := []struct {
		ctx  context.Context
		fmts string
		args []interface{}
		want error
	}{
		{
			ctx:  context.Background(),
			fmts: "Hello world",
			want: errors.New("Hello world"),
		},
		{
			ctx:  PrefixErr(context.Background(), "file: foo: "),
			fmts: "Hello world: %d",
			args: []interface{}{1},
			want: errors.New("file: foo: Hello world: 1"),
		},
		{
			ctx:  PrefixErr(PrefixErr(context.Background(), "file: foo: "), "tag: <resources>: "),
			fmts: "Hello world: %d",
			args: []interface{}{1},
			want: errors.New("file: foo: tag: <resources>: Hello world: 1"),
		},
	}
	for _, tc := range tests {
		got := Errorf(tc.ctx, tc.fmts, tc.args...)
		if !reflect.DeepEqual(got, tc.want) {
			t.Errorf("Errorf(%v, %v, %v): %v wanted %v", tc.ctx, tc.fmts, tc.args, got, tc.want)
		}
	}
}
