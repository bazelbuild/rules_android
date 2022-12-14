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

package extractaar

import (
	"fmt"
	"strings"
)

// BuildozerError represent a rule configuration error fixable with a buildozer command.
type BuildozerError struct {
	Msg      string
	RuleAttr string
	NewValue string
}

func mergeBuildozerErrors(label string, errs []*BuildozerError) string {
	var msg strings.Builder
	msg.WriteString(fmt.Sprintf("error(s) found while processing aar '%s':\n", label))
	var buildozerCommand strings.Builder
	buildozerCommand.WriteString("Use the following command to fix the target:\nbuildozer ")
	useBuildozer := false
	for _, err := range errs {
		msg.WriteString(fmt.Sprintf("\t- %s\n", err.Msg))
		if err.NewValue != "" {
			useBuildozer = true
			buildozerCommand.WriteString(fmt.Sprintf("'set %s %s' ", err.RuleAttr, err.NewValue))
		}
	}
	buildozerCommand.WriteString(label)

	if useBuildozer {
		msg.WriteString(buildozerCommand.String())
	}
	return msg.String()
}
