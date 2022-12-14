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
	"context"
	"errors"
	"reflect"
	"testing"
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
			ctx:  prefixErr(context.Background(), "file: foo: "),
			fmts: "Hello world: %d",
			args: []interface{}{1},
			want: errors.New("file: foo: Hello world: 1"),
		},
		{
			ctx:  prefixErr(prefixErr(context.Background(), "file: foo: "), "tag: <resources>: "),
			fmts: "Hello world: %d",
			args: []interface{}{1},
			want: errors.New("file: foo: tag: <resources>: Hello world: 1"),
		},
	}
	for _, tc := range tests {
		got := errorf(tc.ctx, tc.fmts, tc.args...)
		if !reflect.DeepEqual(got, tc.want) {
			t.Errorf("Errorf(%v, %v, %v): %v wanted %v", tc.ctx, tc.fmts, tc.args, got, tc.want)
		}
	}
}

func TestMergeErrStreams(t *testing.T) {
	ctx := context.Background()
	sendClose := func(e error, eC chan<- error) {
		defer close(eC)
		eC <- e
	}
	in1 := make(chan error)
	in2 := make(chan error)
	go sendClose(errors.New("hi"), in1)
	go sendClose(errors.New("hello"), in2)
	merged := mergeErrStreams(ctx, []<-chan error{in1, in2})
	var rcv []error
	for r := range merged {
		rcv = append(rcv, r)
	}
	if len(rcv) != 2 {
		t.Errorf("got: %v on merged stream, wanted only 2 elements", rcv)
	}
}
