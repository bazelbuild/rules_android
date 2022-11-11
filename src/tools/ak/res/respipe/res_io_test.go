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
	"bytes"
	"context"
	"testing"

	rdpb "src/tools/ak/res/proto/res_data_go_proto"
	"google.golang.org/protobuf/proto"
)

func TestProduceConsume(t *testing.T) {
	var b bytes.Buffer

	ro := ResOutput{Out: &b}
	resC := make(chan *rdpb.Resource)
	ctx, cxlFn := context.WithCancel(context.Background())
	defer cxlFn()

	errC := ro.Consume(ctx, resC)
	ress := []*rdpb.Resource{
		{
			Name: "hi",
		},
		{
			Name: "bye",
		},
		{
			Name: "foo",
		},
	}
	for _, r := range ress {
		select {
		case err := <-errC:
			t.Fatalf("Unexpected err: %v", err)
		case resC <- r:
		}
	}
	close(resC)
	if err := <-errC; err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	ri := ResInput{In: &b}

	resInC, errC := ri.Produce(ctx)
	var got []*rdpb.Resource
	for resInC != nil || errC != nil {
		select {
		case r, ok := <-resInC:
			if !ok {
				resInC = nil
				continue
			}
			got = append(got, r)
		case err, ok := <-errC:
			if !ok {
				errC = nil
				continue
			}
			t.Fatalf("Unexpected err: %v", err)
		}
	}
	if len(got) != len(ress) {
		t.Fatalf("Got %d elements, expected %d", len(got), len(ress))
	}
	for i := range ress {
		if !proto.Equal(got[i], ress[i]) {
			t.Errorf("Got: %+v wanted: %+v", got[i], ress[i])
		}
	}
}
