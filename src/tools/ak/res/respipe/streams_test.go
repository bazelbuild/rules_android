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
	"context"
	"errors"
	"testing"

	rdpb "src/tools/ak/res/proto/res_data_go_proto"
	"src/tools/ak/res/res"
)

func TestMergePathInfoStreams(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	sendClose := func(p *res.PathInfo, c chan<- *res.PathInfo) {
		defer close(c)
		c <- p
	}
	in1 := make(chan *res.PathInfo)
	in2 := make(chan *res.PathInfo)
	go sendClose(&res.PathInfo{}, in1)
	go sendClose(&res.PathInfo{}, in2)
	mergedC := MergePathInfoStreams(ctx, []<-chan *res.PathInfo{in1, in2})
	var rcv []*res.PathInfo
	for p := range mergedC {
		rcv = append(rcv, p)
	}
	if len(rcv) != 2 {
		t.Errorf("got: %v on merged stream, wanted only 2 elements", rcv)
	}
}

func TestMergeResStreams(t *testing.T) {
	ctx := context.Background()
	sendClose := func(r *rdpb.Resource, c chan<- *rdpb.Resource) {
		defer close(c)
		c <- r
	}
	in1 := make(chan *rdpb.Resource)
	in2 := make(chan *rdpb.Resource)
	go sendClose(&rdpb.Resource{}, in1)
	go sendClose(&rdpb.Resource{}, in2)
	merged := MergeResStreams(ctx, []<-chan *rdpb.Resource{in1, in2})
	var rcv []*rdpb.Resource
	for r := range merged {
		rcv = append(rcv, r)
	}
	if len(rcv) != 2 {
		t.Errorf("got: %v on merged stream, wanted only 2 elements", rcv)
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
	merged := MergeErrStreams(ctx, []<-chan error{in1, in2})
	var rcv []error
	for r := range merged {
		rcv = append(rcv, r)
	}
	if len(rcv) != 2 {
		t.Errorf("got: %v on merged stream, wanted only 2 elements", rcv)
	}
}
