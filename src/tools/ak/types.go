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

// Package types provides globally used types.
package types

type initFunc func()
type runFunc func()
type descFunc func() string

/*
Command is used to specify a command.

  Init:
    Entry point to initialize the command.
  Run:
    Entry point to run the command.
  Flags:
    (Optional) Flags that are used by the command.
  Desc:
    A short description of the command.
*/
type Command struct {
	Init  initFunc
	Run   runFunc
	Flags []string
	Desc  descFunc
}
