// Copyright 2023 The Bazel Authors. All rights reserved.
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

// Package akcommands provides a map of all AK commands to their respective binaries.
package akcommands

import (
	"src/tools/ak/bucketize/bucketize"
	"src/tools/ak/compile/compile"
	"src/tools/ak/dex/dex"
	"src/tools/ak/extractaar/extractaar"
	"src/tools/ak/finalrjar/finalrjar"
	"src/tools/ak/generatemanifest/generatemanifest"
	"src/tools/ak/link/link"
	"src/tools/ak/liteparse/liteparse"
	"src/tools/ak/manifest/manifest"
	"src/tools/ak/mindex/mindex"
	"src/tools/ak/nativelib/nativelib"
	"src/tools/ak/patch/patch"
	"src/tools/ak/repack/repack"
	"src/tools/ak/rjar/rjar"
	"src/tools/ak/shellapk/shellapk"
	"src/tools/ak/types"
)

var (
	// Cmds map AK commands to their respective binaries
	Cmds = map[string]types.Command{
		"bucketize":        bucketize.Cmd,
		"compile":          compile.Cmd,
		"dex":              dex.Cmd,
		"extractaar":       extractaar.Cmd,
		"link":             link.Cmd,
		"liteparse":        liteparse.Cmd,
		"generatemanifest": generatemanifest.Cmd,
		"manifest":         manifest.Cmd,
		"mindex":           mindex.Cmd,
		"nativelib":        nativelib.Cmd,
		"patch":            patch.Cmd,
		"repack":           repack.Cmd,
		"rjar":             rjar.Cmd,
		"finalrjar":        finalrjar.Cmd,
		"shellapk":         shellapk.Cmd,
	}
)
