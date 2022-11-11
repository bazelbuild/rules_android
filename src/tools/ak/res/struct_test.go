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

package res

import (
	"fmt"
	"strings"
	"testing"
)

func TestKinds(t *testing.T) {
	tests := []struct {
		t Type
		k Kind
	}{
		{t: String, k: Value},
		{t: XML, k: NonValue},
		{t: Drawable, k: NonValue},
		{t: Color, k: Both},
		{t: Menu, k: NonValue},
		{t: Dimen, k: Value},
		{t: UnknownType, k: Unknown},
	}
	for _, tc := range tests {
		if tc.t.Kind() != tc.k {
			t.Errorf("%v.Kind() = %v want: %v", tc.t, tc.t.Kind(), tc.k)
		}
	}
	for _, at := range AllTypes {
		if at == UnknownType {
			continue
		}
		if at.Kind() == Unknown {
			t.Errorf("%v.Kind() = %v - wanting anything else but that", at, Unknown)
		}
	}
}

func TestTypes(t *testing.T) {
	tests := []struct {
		t Type
		s string
	}{
		{t: String, s: "string"},
		{t: XML, s: "xml"},
		{t: Drawable, s: "drawable"},
		{t: Color, s: "color"},
		{t: Menu, s: "menu"},
		{t: Dimen, s: "dimen"},
	}

	for _, tc := range tests {
		pt, err := ParseType(tc.s)
		if tc.t != pt || err != nil {
			t.Errorf("ParseType(%s): %v, %v want: %v", tc.s, pt, err, tc.t)
		}
	}
}

func TestDensities(t *testing.T) {
	tests := []struct {
		arg  string
		want Density
		err  error
	}{
		{arg: "tvdpi", want: TVDPI},
		{arg: "hdpi", want: HDPI},
		{arg: "320dpi", want: 320},
		{arg: "nodpi", want: NoDPI},
		{arg: "en-US", want: UnspecifiedDensity},
		{arg: "12000000dpi", err: fmt.Errorf("%ddpi: unparsable", 12000000)},
	}

	for _, tc := range tests {
		got, err := ParseDensity(tc.arg)
		if tc.err == nil && err != nil {
			t.Errorf("ParseDensity(%s): got err: %s", tc.arg, err)
		}
		if tc.err != nil && err != nil && !strings.HasPrefix(err.Error(), tc.err.Error()) {
			t.Errorf("ParseDensity(%s): got err: %v want err: %v", tc.arg, err, tc.err)
		}

		if got != tc.want {
			t.Errorf("ParseDensity(%s): Got: %v want: %v", tc.arg, got, tc.want)
		}
	}
}
