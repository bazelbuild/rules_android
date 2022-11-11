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
	"reflect"
	"strings"
	"testing"
)

func TestNaming(t *testing.T) {
	tests := []struct {
		unparsed      string
		resType       Type
		want          FullyQualifiedName
		wantErrPrefix string
	}{
		{
			"style/InlineProjectStyle",
			ValueType,
			FullyQualifiedName{
				Name:    "InlineProjectStyle",
				Type:    Style,
				Package: "res-auto",
			},
			"",
		},
		{
			"android:style/InlineProjectStyle",
			ValueType,
			FullyQualifiedName{
				Name:    "InlineProjectStyle",
				Type:    Style,
				Package: "android",
			},
			"",
		},
		{
			"@style/InlineProjectStyle",
			ValueType,
			FullyQualifiedName{
				Name:    "InlineProjectStyle",
				Type:    Style,
				Package: "res-auto",
			},
			"",
		},
		{
			"@style/android:InlineProjectStyle",
			ValueType,
			FullyQualifiedName{
				Name:    "InlineProjectStyle",
				Type:    Style,
				Package: "android",
			},
			"",
		},
		{
			"?style/InlineProjectStyle",
			ValueType,
			FullyQualifiedName{
				Name:    "InlineProjectStyle",
				Type:    Style,
				Package: "res-auto",
			},
			"",
		},
		{
			"?style/android:InlineProjectStyle",
			ValueType,
			FullyQualifiedName{
				Name:    "InlineProjectStyle",
				Type:    Style,
				Package: "android",
			},
			"",
		},
		{
			"android:style/Widget.TextView",
			ValueType,
			FullyQualifiedName{
				Name:    "Widget.TextView",
				Type:    Style,
				Package: "android",
			},
			"",
		},
		{
			"@android:style/Widget.TextView",
			ValueType,
			FullyQualifiedName{
				Name:    "Widget.TextView",
				Type:    Style,
				Package: "android",
			},
			"",
		},
		{
			"?android:style/Widget.TextView",
			ValueType,
			FullyQualifiedName{
				Name:    "Widget.TextView",
				Type:    Style,
				Package: "android",
			},
			"",
		},
		{
			"?attr/styleReference",
			ValueType,
			FullyQualifiedName{
				Name:    "styleReference",
				Type:    Attr,
				Package: "res-auto",
			},
			"",
		},
		{
			"?android:attr/textAppearance",
			ValueType,
			FullyQualifiedName{
				Name:    "textAppearance",
				Type:    Attr,
				Package: "android",
			},
			"",
		},
		{
			"?attr/android:textAppearance",
			ValueType,
			FullyQualifiedName{
				Name:    "textAppearance",
				Type:    Attr,
				Package: "android",
			},
			"",
		},
		{
			"@dimen/viewer:progress_bar_height",
			ValueType,
			FullyQualifiedName{
				Name:    "progress_bar_height",
				Type:    Dimen,
				Package: "viewer",
			},
			"",
		},
		{
			"drawable/simple",
			Drawable,
			FullyQualifiedName{
				Name:    "simple",
				Type:    Drawable,
				Package: "res-auto",
			},
			"",
		},
		{
			"android:fraction/name",
			ValueType,
			FullyQualifiedName{
				Name:    "name",
				Type:    Fraction,
				Package: "android",
			},
			"",
		},
		{
			"android:style/foo:with_colon",
			ValueType,
			FullyQualifiedName{
				Name:    "foo:with_colon",
				Type:    Style,
				Package: "android",
			},
			"",
		},
		{
			"color/red",
			ValueType,
			FullyQualifiedName{
				Name:    "red",
				Type:    Color,
				Package: "res-auto",
			},
			"",
		},
		{
			"style/bright:with_colon",
			ValueType,
			FullyQualifiedName{
				Name:    "with_colon",
				Type:    Style,
				Package: "bright",
			},
			"",
		},
		{
			"com.google.android.apps.gmoney:array/available_locales",
			ValueType,
			FullyQualifiedName{
				Name:    "available_locales",
				Type:    Array,
				Package: "com.google.android.apps.gmoney",
			},
			"",
		},
		{
			"@android:string/ok",
			ValueType,
			FullyQualifiedName{
				Name:    "ok",
				Type:    String,
				Package: "android",
			},
			"",
		},
		{
			"@string/android:ok",
			ValueType,
			FullyQualifiedName{
				Name:    "ok",
				Type:    String,
				Package: "android",
			},
			"",
		},
		{
			"name",
			String,
			FullyQualifiedName{
				Package: "res-auto",
				Type:    String,
				Name:    "name",
			},
			"",
		},
		{
			"string/name",
			String,
			FullyQualifiedName{
				Package: "res-auto",
				Type:    String,
				Name:    "name",
			},
			"",
		},
		{
			"android:Theme.Material.Light",
			Style,
			FullyQualifiedName{
				Package: "android",
				Type:    Style,
				Name:    "Theme.Material.Light",
			},
			"",
		},
		{
			"@android:attr/borderlessButtonStyle",
			Style,
			FullyQualifiedName{
				Package: "android",
				Type:    Attr,
				Name:    "borderlessButtonStyle",
			},
			"",
		},
		{
			"@id/:packagelessId",
			Style,
			FullyQualifiedName{
				Package: "res-auto",
				Type:    ID,
				Name:    "packagelessId",
			},
			"",
		},
		{
			"InlineProjectStyle",
			UnknownType,
			FullyQualifiedName{},
			"cannot determine type",
		},
		{
			"android:InlineProjectStyle",
			UnknownType,
			FullyQualifiedName{},
			"cannot determine type",
		},
		{
			"res-auto:InlineProjectStyle",
			UnknownType,
			FullyQualifiedName{},
			"cannot determine type",
		},
		{
			"style/",
			ValueType,
			FullyQualifiedName{},
			"cannot determine name",
		},
		{
			":style/InlineProjectStyle",
			ValueType,
			FullyQualifiedName{},
			"malformed name",
		},
		{
			"/InlineProjectStyle",
			ValueType,
			FullyQualifiedName{},
			"malformed name",
		},
	}

	for _, tc := range tests {
		got, gotErr := ParseName(tc.unparsed, tc.resType)
		if !reflect.DeepEqual(got, tc.want) {
			t.Errorf("ParseName(%s, %+v): got: %#v want: %#v", tc.unparsed, tc.resType, got, tc.want)
		}

		if gotErr != nil && ("" == tc.wantErrPrefix || !strings.HasPrefix(gotErr.Error(), tc.wantErrPrefix)) {
			t.Errorf("ParseName(%s, %+v): %v want prefix: %s", tc.unparsed, tc.resType, gotErr, tc.wantErrPrefix)
		}
		if gotErr == nil && "" != tc.wantErrPrefix {
			t.Errorf("ParseName(%s, %+v): got no err want err prefix: %s", tc.unparsed, tc.resType, tc.wantErrPrefix)
		}
	}
}
