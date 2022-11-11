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

// Package respipe contains utilities for running pipelines on android resources.
package respipe

import (
	"context"
	"sync"

	rdpb "src/tools/ak/res/proto/res_data_go_proto"
	"src/tools/ak/res/res"
)

// MergePathInfoStreams fans in multiple PathInfo streams into a single stream.
func MergePathInfoStreams(ctx context.Context, piCs []<-chan *res.PathInfo) <-chan *res.PathInfo {
	piC := make(chan *res.PathInfo)
	var wg sync.WaitGroup
	wg.Add(len(piCs))
	output := func(c <-chan *res.PathInfo) {
		defer wg.Done()
		for r := range c {
			select {
			case piC <- r:
			case <-ctx.Done():
				return
			}
		}
	}
	for _, rc := range piCs {
		go output(rc)
	}
	go func() {
		wg.Wait()
		close(piC)
	}()
	return piC
}

// MergeResStreams fans in multiple Resource streams into a single stream.
func MergeResStreams(ctx context.Context, resCs []<-chan *rdpb.Resource) <-chan *rdpb.Resource {
	resC := make(chan *rdpb.Resource)
	var wg sync.WaitGroup
	wg.Add(len(resCs))
	output := func(c <-chan *rdpb.Resource) {
		defer wg.Done()
		for r := range c {
			select {
			case resC <- r:
			case <-ctx.Done():
				return
			}
		}
	}
	for _, rc := range resCs {
		go output(rc)
	}
	go func() {
		wg.Wait()
		close(resC)
	}()
	return resC
}

// MergeErrStreams fans in multiple error streams into a single stream.
func MergeErrStreams(ctx context.Context, errCs []<-chan error) <-chan error {
	errC := make(chan error)
	var wg sync.WaitGroup
	wg.Add(len(errCs))
	output := func(c <-chan error) {
		defer wg.Done()
		for e := range c {
			select {
			case errC <- e:
			case <-ctx.Done():
				return
			}
		}
	}
	for _, rc := range errCs {
		go output(rc)
	}
	go func() {
		wg.Wait()
		close(errC)
	}()
	return errC
}

// SendErr attempts to send the provided error to the provided chan, however is the context is canceled, it will return false.
func SendErr(ctx context.Context, errC chan<- error, err error) bool {
	select {
	case <-ctx.Done():
		return false
	case errC <- err:
		return true
	}
}

// SendRes attempts to send the provided resource to the provided chan, however is the context is canceled, it will return false.
func SendRes(ctx context.Context, resC chan<- *rdpb.Resource, r *rdpb.Resource) bool {
	select {
	case <-ctx.Done():
		return false
	case resC <- r:
		return true
	}
}
