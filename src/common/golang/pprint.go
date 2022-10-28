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

// Package pprint provides colored "pretty print" output helper methods
package pprint

import (
	"fmt"
	"os"
)

const (
	errorString   = "\033[1m\033[31mERROR:\033[0m %s\n"
	warningString = "\033[35mWARNING:\033[0m %s\n"
	infoString    = "\033[32mINFO:\033[0m %s\n"
	clearLine     = "\033[A\033[K"
)

// Error prints an error message in bazel style colors
func Error(errorMsg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, errorString, fmt.Sprintf(errorMsg, args...))
}

// Warning prints a warning message in bazel style colors
func Warning(warningMsg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, warningString, fmt.Sprintf(warningMsg, args...))
}

// Info prints an info message in bazel style colors
func Info(infoMsg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, infoString, fmt.Sprintf(infoMsg, args...))
}

// ClearLine deletes the line above the cursor's current position.
func ClearLine() {
	fmt.Printf(clearLine)
}
