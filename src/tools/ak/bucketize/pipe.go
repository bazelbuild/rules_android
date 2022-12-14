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
	"fmt"
	"strings"
	"sync"

	"src/tools/ak/res/res"
)

type contextKey int

const (
	ctxErr contextKey = 0
)

// errorf returns a formatted error with any context sensitive information prefixed to the error
func errorf(ctx context.Context, fmts string, a ...interface{}) error {
	if s, ok := ctx.Value(ctxErr).(string); ok {
		return fmt.Errorf(strings.Join([]string{s, fmts}, ""), a...)
	}
	return fmt.Errorf(fmts, a...)
}

// prefixErr returns a context which adds a prefix to error messages.
func prefixErr(ctx context.Context, add string) context.Context {
	if s, ok := ctx.Value(ctxErr).(string); ok {
		return context.WithValue(ctx, ctxErr, strings.Join([]string{s, add}, ""))
	}
	return context.WithValue(ctx, ctxErr, add)
}

func separatePathInfosByValues(ctx context.Context, pis []*res.PathInfo) (<-chan *res.PathInfo, <-chan *res.PathInfo) {
	valuesPIC := make(chan *res.PathInfo)
	nonValuesPIC := make(chan *res.PathInfo)
	go func() {
		defer close(valuesPIC)
		defer close(nonValuesPIC)
		for _, pi := range pis {
			if pi.Type.Kind() == res.Value || pi.Type.Kind() == res.Both && strings.HasPrefix(pi.TypeDir, "values") {
				select {
				case valuesPIC <- pi:
				case <-ctx.Done():
					return
				}
			} else {
				select {
				case nonValuesPIC <- pi:
				case <-ctx.Done():
					return
				}
			}
		}
	}()
	return valuesPIC, nonValuesPIC
}

func mergeValuesResourceStreams(ctx context.Context, vrCs []<-chan *res.ValuesResource) <-chan *res.ValuesResource {
	vrC := make(chan *res.ValuesResource)
	var wg sync.WaitGroup
	wg.Add(len(vrCs))
	output := func(c <-chan *res.ValuesResource) {
		defer wg.Done()
		for vr := range c {
			select {
			case vrC <- vr:
			case <-ctx.Done():
				return
			}
		}
	}
	for _, c := range vrCs {
		go output(c)
	}
	go func() {
		wg.Wait()
		close(vrC)
	}()
	return vrC
}

func mergeResourcesAttributeStreams(ctx context.Context, raCs []<-chan *ResourcesAttribute) <-chan *ResourcesAttribute {
	raC := make(chan *ResourcesAttribute)
	var wg sync.WaitGroup
	wg.Add(len(raCs))
	output := func(c <-chan *ResourcesAttribute) {
		defer wg.Done()
		for ra := range c {
			select {
			case raC <- ra:
			case <-ctx.Done():
				return
			}
		}
	}
	for _, c := range raCs {
		go output(c)
	}
	go func() {
		wg.Wait()
		close(raC)
	}()
	return raC
}

// mergeErrStreams fans in multiple error streams into a single stream.
func mergeErrStreams(ctx context.Context, errCs []<-chan error) <-chan error {
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

// sendErr attempts to send the provided error to the provided chan, however is the context is canceled, it will return false.
func sendErr(ctx context.Context, errC chan<- error, err error) bool {
	select {
	case <-ctx.Done():
		return false
	case errC <- err:
		return true
	}
}
