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
	"fmt"
	"strings"

	"context"
)

const (
	ctxErrPrefix = "err-prefix"
)

// Errorf returns a formatted error with any context sensitive information prefixed to the error
func Errorf(ctx context.Context, fmts string, a ...interface{}) error {
	if s, ok := ctx.Value(ctxErrPrefix).(string); ok {
		return fmt.Errorf(strings.Join([]string{s, fmts}, ""), a...)
	}
	return fmt.Errorf(fmts, a...)
}

// PrefixErr returns a context which adds a prefix to error messages.
func PrefixErr(ctx context.Context, add string) context.Context {
	if s, ok := ctx.Value(ctxErrPrefix).(string); ok {
		return context.WithValue(ctx, ctxErrPrefix, strings.Join([]string{s, add}, ""))
	}
	return context.WithValue(ctx, ctxErrPrefix, add)

}
