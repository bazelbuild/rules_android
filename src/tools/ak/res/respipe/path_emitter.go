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
	"fmt"
	"os"
	"path/filepath"

	"src/tools/ak/res/res"
)

// EmitPathInfos takes the list of provided PathInfos and emits them via its returned channel.
func EmitPathInfos(ctx context.Context, pis []*res.PathInfo) <-chan *res.PathInfo {
	// produce PathInfos from res files
	piC := make(chan *res.PathInfo)
	go func() {
		defer close(piC)
		for _, pi := range pis {
			select {
			case piC <- pi:
			case <-ctx.Done():
				return
			}
		}
	}()
	return piC
}

// EmitPathInfosDir descends a provided directory and emits PathInfo objects via its returned
// channel. It also emits any errors encountered during the walk to its error channel.
func EmitPathInfosDir(ctx context.Context, base string) (<-chan *res.PathInfo, <-chan error) {
	piC := make(chan *res.PathInfo)
	errC := make(chan error)
	go func() {
		defer close(piC)
		defer close(errC)
		emit := func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return fmt.Errorf("%s: walk failed: %v", path, err)
			}
			if info.IsDir() {
				// we do not care about dirs.
				return nil
			}
			pi, err := res.ParsePath(path)
			if err == res.ErrNotResPath || err == res.ErrSkipResPath {
				return nil
			}
			if err != nil {
				if !SendErr(ctx, errC, Errorf(ctx, "%s: unexpected PathInfo failure: %v", path, err)) {
					return filepath.SkipDir
				}
				return nil
			}
			select {
			case <-ctx.Done():
				return filepath.SkipDir
			case piC <- &pi:
			}
			return nil
		}
		if err := filepath.Walk(base, emit); err != nil {
			SendErr(ctx, errC, Errorf(ctx, "%s: walk encountered err: %v", base, err))
		}
	}()
	return piC, errC
}

// EmitPathInfosDirs descends a provided directories and emits PathsInfo objects via its returned
// channel. It also emits any errors encountered during the walk to its error channel.
func EmitPathInfosDirs(ctx context.Context, dirs []string) (<-chan *res.PathInfo, <-chan error) {
	piCs := make([]<-chan *res.PathInfo, 0, len(dirs))
	errCs := make([]<-chan error, 0, len(dirs))
	for _, rd := range dirs {
		piC, piErr := EmitPathInfosDir(ctx, rd)
		piCs = append(piCs, piC)
		errCs = append(errCs, piErr)
	}
	return MergePathInfoStreams(ctx, piCs), MergeErrStreams(ctx, errCs)
}
