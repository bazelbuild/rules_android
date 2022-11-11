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
	"testing"
)

func TestParsePath(t *testing.T) {
	tests := []struct {
		arg  string
		want PathInfo
	}{
		{
			"/tmp/foobar/values/strings.xml",
			PathInfo{
				Path:    "/tmp/foobar/values/strings.xml",
				Type:    ValueType,
				TypeDir: "values",
				ResDir:  "/tmp/foobar",
			},
		},
		{
			"/tmp/foobar/values-v19/strings.xml",
			PathInfo{
				Path:      "/tmp/foobar/values-v19/strings.xml",
				Type:      ValueType,
				TypeDir:   "values-v19",
				ResDir:    "/tmp/foobar",
				Qualifier: "v19",
			},
		},
		{
			"/tmp/baz/foobar/layout-es-419/main_activity.xml",
			PathInfo{
				Path:      "/tmp/baz/foobar/layout-es-419/main_activity.xml",
				Type:      Layout,
				TypeDir:   "layout-es-419",
				ResDir:    "/tmp/baz/foobar",
				Qualifier: "es-419",
			},
		},
		{
			"/tmp/baz/foobar/menu/menu_data.xml",
			PathInfo{
				Path:    "/tmp/baz/foobar/menu/menu_data.xml",
				Type:    Menu,
				TypeDir: "menu",
				ResDir:  "/tmp/baz/foobar",
			},
		},
		{
			"tmp/baz/foobar/drawable-en-ldpi/mercury.png",
			PathInfo{
				Path:      "tmp/baz/foobar/drawable-en-ldpi/mercury.png",
				Type:      Drawable,
				TypeDir:   "drawable-en-ldpi",
				ResDir:    "tmp/baz/foobar",
				Qualifier: "en-ldpi",
				Density:   120,
			},
		},
		{
			"tmp/baz/foobar/drawable-fr-mdpi-nokeys/mars.xml",
			PathInfo{
				Path:      "tmp/baz/foobar/drawable-fr-mdpi-nokeys/mars.xml",
				Type:      Drawable,
				TypeDir:   "drawable-fr-mdpi-nokeys",
				ResDir:    "tmp/baz/foobar",
				Qualifier: "fr-mdpi-nokeys",
				Density:   160,
			},
		},

		{
			"tmp/baz/foobar/drawable-mcc310-en-rUS-tvdpi/venus.jpg",
			PathInfo{
				Path:      "tmp/baz/foobar/drawable-mcc310-en-rUS-tvdpi/venus.jpg",
				Type:      Drawable,
				TypeDir:   "drawable-mcc310-en-rUS-tvdpi",
				ResDir:    "tmp/baz/foobar",
				Qualifier: "mcc310-en-rUS-tvdpi",
				Density:   213,
			},
		},
		{
			"tmp/baz/foobar/drawable-mcc208-mnc00-fr-rCA-hdpi-12key-dpad/earth.gif",
			PathInfo{
				Path:      "tmp/baz/foobar/drawable-mcc208-mnc00-fr-rCA-hdpi-12key-dpad/earth.gif",
				Type:      Drawable,
				TypeDir:   "drawable-mcc208-mnc00-fr-rCA-hdpi-12key-dpad",
				ResDir:    "tmp/baz/foobar",
				Qualifier: "mcc208-mnc00-fr-rCA-hdpi-12key-dpad",
				Density:   240,
			},
		},
		{
			"tmp/baz/foobar/drawable-xhdpi/neptune.jpg",
			PathInfo{
				Path:      "tmp/baz/foobar/drawable-xhdpi/neptune.jpg",
				Type:      Drawable,
				TypeDir:   "drawable-xhdpi",
				ResDir:    "tmp/baz/foobar",
				Qualifier: "xhdpi",
				Density:   320,
			},
		},
		{
			"tmp/baz/foobar/drawable-xxhdpi/uranus.png",
			PathInfo{
				Path:      "tmp/baz/foobar/drawable-xxhdpi/uranus.png",
				Type:      Drawable,
				TypeDir:   "drawable-xxhdpi",
				ResDir:    "tmp/baz/foobar",
				Qualifier: "xxhdpi",
				Density:   480,
			},
		},
		{
			"tmp/baz/foobar/drawable-xxxhdpi/saturn.xml",
			PathInfo{
				Path:      "tmp/baz/foobar/drawable-xxxhdpi/saturn.xml",
				Type:      Drawable,
				TypeDir:   "drawable-xxxhdpi",
				ResDir:    "tmp/baz/foobar",
				Qualifier: "xxxhdpi",
				Density:   640,
			},
		},
		{
			"tmp/baz/foobar/drawable-anydpi/jupiter.png",
			PathInfo{
				Path:      "tmp/baz/foobar/drawable-anydpi/jupiter.png",
				Type:      Drawable,
				TypeDir:   "drawable-anydpi",
				ResDir:    "tmp/baz/foobar",
				Qualifier: "anydpi",
				Density:   AnyDPI,
			},
		},
		{
			"tmp/baz/foobar/drawable-nodpi/sun.gif",
			PathInfo{
				Path:      "tmp/baz/foobar/drawable-nodpi/sun.gif",
				Type:      Drawable,
				TypeDir:   "drawable-nodpi",
				ResDir:    "tmp/baz/foobar",
				Qualifier: "nodpi",
				Density:   NoDPI,
			},
		},
		{
			"tmp/baz/foobar/drawable-120dpi/moon.xml",
			PathInfo{
				Path:      "tmp/baz/foobar/drawable-120dpi/moon.xml",
				Type:      Drawable,
				TypeDir:   "drawable-120dpi",
				ResDir:    "tmp/baz/foobar",
				Qualifier: "120dpi",
				Density:   120,
			},
		},
	}
	for _, tc := range tests {
		got, err := ParsePath(tc.arg)
		if err != nil {
			t.Errorf("ParsePath(%s): got err: %s", tc.arg, err)
			continue
		}
		if !reflect.DeepEqual(got, tc.want) {
			t.Errorf("ParsePath(%s): got %+v want: %+v", tc.arg, got, tc.want)
		}
	}
}

func TestParsePath_NegativeCases(t *testing.T) {
	tests := []struct {
		arg string
		err error
	}{
		{"/foo/bar/baz/strings.xml", ErrNotResPath},
		{"strings.xml", ErrNotResPath},
	}
	for _, tc := range tests {
		got, err := ParsePath(tc.arg)
		if err == nil {
			t.Errorf("ParsePath(%s): got: %+v and nil err, want err: %v", tc.arg, got, tc.err)
		}
		if err != tc.err {
			t.Errorf("ParsePath(%s): got err: %v want err: %v", tc.arg, err, tc.err)
		}
	}
}

func TestMakePathInfo(t *testing.T) {
	paths := []string{
		"/tmp/foobar/values/strings.xml",
		"/tmp/foobar/values-v19/strings.xml",
		"/tmp/foobar/values-v19/.skip_me.xml",
		"/tmp/baz/foobar/menu/menu_data.xml",
		"tmp/baz/foobar/drawable-en-ldpi/mercury.png",
		"/tmp/foobar/values-v19/.skip_me_as_well.xml",
	}
	want := []*PathInfo{
		&PathInfo{
			Path:    "/tmp/foobar/values/strings.xml",
			Type:    ValueType,
			TypeDir: "values",
			ResDir:  "/tmp/foobar"},
		&PathInfo{
			Path:      "/tmp/foobar/values-v19/strings.xml",
			Type:      ValueType,
			TypeDir:   "values-v19",
			ResDir:    "/tmp/foobar",
			Qualifier: "v19"},
		&PathInfo{
			Path:    "/tmp/baz/foobar/menu/menu_data.xml",
			Type:    Menu,
			TypeDir: "menu",
			ResDir:  "/tmp/baz/foobar"},
		&PathInfo{
			Path:      "tmp/baz/foobar/drawable-en-ldpi/mercury.png",
			Type:      Drawable,
			TypeDir:   "drawable-en-ldpi",
			ResDir:    "tmp/baz/foobar",
			Qualifier: "en-ldpi",
			Density:   120},
	}
	pInfos, err := MakePathInfos(paths)
	if err != nil {
		t.Fatalf("MakePathInfos unexpected error: %v", err)
	}
	if !reflect.DeepEqual(pInfos, want) {
		t.Errorf("MakePathInfos: got %+v want: %+v", pInfos, want)
	}
}
