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

// Package finalrjar generates a valid final R.jar.
package finalrjar

import (
	"bytes"
	"sort"
	"strings"
	"testing"

	"github.com/google/go-cmp/cmp"
)

type fakeFile struct {
	reader *strings.Reader
}

func (f fakeFile) Read(b []byte) (int, error) {
	return f.reader.Read(b)
}

func (f fakeFile) Close() error {
	return nil
}

func TestGetIds(t *testing.T) {
	tests := []struct {
		name              string
		rtxtFiles         []*strings.Reader
		expectedResources []*resource
	}{
		{
			name: "one R.txt",
			rtxtFiles: []*strings.Reader{
				strings.NewReader(
					`int anim abc_fade_in 0
int anim abc_fade_out 0
int attr actionBarDivider 0
int bool abc_action_bar_embed_tabs 0
int color abc_background_cache_hint_selector_material_dark 0
int[] color abc_background_cache_hint_selector_material_light 0
int color abc_btn_colored_borderless_text_material 0
int dimen tooltip_y_offset_non_touch 0
int dimen $avd_hide_password__0 0
int[] dimen tooltip_y_offset_touch 0
int drawable abc_ab_share_pack_mtrl_alpha 0`),
			},
			expectedResources: []*resource{
				&resource{ID: "abc_ab_share_pack_mtrl_alpha", resType: "drawable", varType: "int"},
				&resource{ID: "abc_action_bar_embed_tabs", resType: "bool", varType: "int"},
				&resource{ID: "abc_background_cache_hint_selector_material_dark", resType: "color", varType: "int"},
				&resource{ID: "abc_background_cache_hint_selector_material_light", resType: "color", varType: "int[]"},
				&resource{ID: "abc_btn_colored_borderless_text_material", resType: "color", varType: "int"},
				&resource{ID: "abc_fade_in", resType: "anim", varType: "int"},
				&resource{ID: "abc_fade_out", resType: "anim", varType: "int"},
				&resource{ID: "actionBarDivider", resType: "attr", varType: "int"},
				&resource{ID: "tooltip_y_offset_non_touch", resType: "dimen", varType: "int"},
				&resource{ID: "tooltip_y_offset_touch", resType: "dimen", varType: "int[]"},
			},
		},
		{
			name: "multiple R.txt files",
			rtxtFiles: []*strings.Reader{
				strings.NewReader(
					`int styleable toolbar_logo 0
int[] style widget_appcompat_dark 0`),
				strings.NewReader(
					`int layout custom_dialog 0
int interpolator btn_checkbox 0`),
				strings.NewReader(
					`int id view_tree 0
int integer cancel_button_image_alpha 0`),
			},
			expectedResources: []*resource{
				&resource{ID: "btn_checkbox", resType: "interpolator", varType: "int"},
				&resource{ID: "cancel_button_image_alpha", resType: "integer", varType: "int"},
				&resource{ID: "custom_dialog", resType: "layout", varType: "int"},
				&resource{ID: "toolbar_logo", resType: "styleable", varType: "int"},
				&resource{ID: "view_tree", resType: "id", varType: "int"},
				&resource{ID: "widget_appcompat_dark", resType: "style", varType: "int[]"},
			},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			rtxts := make([]rtxtFile, 0, len(tc.rtxtFiles))
			for _, f := range tc.rtxtFiles {
				file := fakeFile{reader: f}
				file.reader.Seek(0, 0)
				rtxts = append(rtxts, file)
			}

			resC := getIds(rtxts)
			receivedResources := make([]*resource, 0)
			for res := range resC {
				receivedResources = append(receivedResources, res)
			}
			sort.Slice(receivedResources, func(i, j int) bool {
				return receivedResources[i].ID < receivedResources[j].ID
			})

			if diff := cmp.Diff(tc.expectedResources, receivedResources, cmp.AllowUnexported(resource{})); diff != "" {
				t.Errorf("getIds(%v) returned diff (-want, +got):\n%v", rtxts, diff)
			}
		})
	}

}

func TestSortResByType(t *testing.T) {
	tests := []struct {
		name        string
		resources   []*resource
		expectedMap map[string][]*resource
	}{
		{
			name: "simple list of resources",
			resources: []*resource{
				&resource{ID: "btn_checkbox", resType: "interpolator", varType: "int"},
				&resource{ID: "cancel_button_image_alpha", resType: "integer", varType: "int"},
				&resource{ID: "custom_dialog", resType: "id", varType: "int"},
				&resource{ID: "toolbar_logo", resType: "interpolator", varType: "int"},
				&resource{ID: "view_tree", resType: "id", varType: "int"},
				&resource{ID: "widget_appcompat_dark", resType: "layout", varType: "int[]"},
			},
			expectedMap: map[string][]*resource{
				"interpolator": []*resource{
					&resource{ID: "btn_checkbox", resType: "interpolator", varType: "int"},
					&resource{ID: "toolbar_logo", resType: "interpolator", varType: "int"},
				},
				"integer": []*resource{
					&resource{ID: "cancel_button_image_alpha", resType: "integer", varType: "int"},
				},
				"id": []*resource{
					&resource{ID: "custom_dialog", resType: "id", varType: "int"},
					&resource{ID: "view_tree", resType: "id", varType: "int"},
				},
				"layout": []*resource{
					&resource{ID: "widget_appcompat_dark", resType: "layout", varType: "int[]"},
				},
			},
		},
		{
			name: "list of resources with duplicates",
			resources: []*resource{
				&resource{ID: "btn_checkbox", resType: "interpolator", varType: "int"},
				&resource{ID: "btn_checkbox", resType: "interpolator", varType: "int"},
				&resource{ID: "cancel_button_image_alpha", resType: "integer", varType: "int"},
				&resource{ID: "custom_dialog", resType: "id", varType: "int"},
				&resource{ID: "toolbar_logo", resType: "interpolator", varType: "int"},
				&resource{ID: "toolbar_logo", resType: "attr", varType: "int"},
				&resource{ID: "view_tree", resType: "id", varType: "int"},
				&resource{ID: "cancel_button_image_alpha", resType: "integer", varType: "int"},
				&resource{ID: "widget_appcompat_dark", resType: "layout", varType: "int[]"},
			},
			expectedMap: map[string][]*resource{
				"attr": []*resource{
					&resource{ID: "toolbar_logo", resType: "attr", varType: "int"},
				},
				"interpolator": []*resource{
					&resource{ID: "btn_checkbox", resType: "interpolator", varType: "int"},
					&resource{ID: "toolbar_logo", resType: "interpolator", varType: "int"},
				},
				"integer": []*resource{
					&resource{ID: "cancel_button_image_alpha", resType: "integer", varType: "int"},
				},
				"id": []*resource{
					&resource{ID: "custom_dialog", resType: "id", varType: "int"},
					&resource{ID: "view_tree", resType: "id", varType: "int"},
				},
				"layout": []*resource{
					&resource{ID: "widget_appcompat_dark", resType: "layout", varType: "int[]"},
				},
			},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			resC := make(chan *resource)
			go func() {
				for _, res := range tc.resources {
					resC <- res
				}
				close(resC)
			}()
			resMap := groupResByType(resC)

			if diff := cmp.Diff(tc.expectedMap, resMap, cmp.AllowUnexported(resource{})); diff != "" {
				t.Errorf("groupResByType(%v) returned diff (-want, +got):\n%v", tc.resources, diff)
			}
		})
	}

}

func TestWriteRJavas(t *testing.T) {
	tests := []struct {
		name              string
		resMap            map[string][]*resource
		pkg               string
		rootPackage       string
		expectedRJava     string
		expectedRootRJava string
	}{
		{
			name: "simple map of resources",
			resMap: map[string][]*resource{
				"interpolator": []*resource{
					&resource{ID: "btn_checkbox", resType: "interpolator", varType: "int"},
					&resource{ID: "toolbar_logo", resType: "interpolator", varType: "int"},
				},
				"integer": []*resource{
					&resource{ID: "cancel_button_image_alpha", resType: "integer", varType: "int"},
				},
				"id": []*resource{
					&resource{ID: "view_tree", resType: "id", varType: "int"},
					&resource{ID: "custom_dialog", resType: "id", varType: "int"},
				},
				"layout": []*resource{
					&resource{ID: "widget_appcompat_dark", resType: "layout", varType: "int[]"},
				},
			},
			pkg:         "com.google.android.apps.sample",
			rootPackage: "mi.rjava",
			expectedRJava: `package com.google.android.apps.sample;
public class R {
  public static class id {
    public static final int custom_dialog=mi.rjava.R.id.custom_dialog;
    public static final int view_tree=mi.rjava.R.id.view_tree;
  }
  public static class integer {
    public static final int cancel_button_image_alpha=mi.rjava.R.integer.cancel_button_image_alpha;
  }
  public static class interpolator {
    public static final int btn_checkbox=mi.rjava.R.interpolator.btn_checkbox;
    public static final int toolbar_logo=mi.rjava.R.interpolator.toolbar_logo;
  }
  public static class layout {
    public static final int[] widget_appcompat_dark=mi.rjava.R.layout.widget_appcompat_dark;
  }
}
`,
			expectedRootRJava: `package mi.rjava;
public class R {
  public static class id {
    public static int custom_dialog=0;
    public static int view_tree=0;
  }
  public static class integer {
    public static int cancel_button_image_alpha=0;
  }
  public static class interpolator {
    public static int btn_checkbox=0;
    public static int toolbar_logo=0;
  }
  public static class layout {
    public static int[] widget_appcompat_dark=null;
  }
}
`,
		},
		{
			name: "with empty class",
			resMap: map[string][]*resource{
				"interpolator": []*resource{
					&resource{ID: "toolbar_logo", resType: "interpolator", varType: "int"},
					&resource{ID: "btn_checkbox", resType: "interpolator", varType: "int"},
				},
				"integer": []*resource{
					&resource{ID: "cancel_button_image_alpha", resType: "integer", varType: "int"},
				},
				"layout": []*resource{
					&resource{ID: "widget_appcompat_dark", resType: "layout", varType: "int[]"},
				},
			},
			pkg:         "com.google.android.apps.empty",
			rootPackage: "mi.rjava",
			expectedRJava: `package com.google.android.apps.empty;
public class R {
  public static class integer {
    public static final int cancel_button_image_alpha=mi.rjava.R.integer.cancel_button_image_alpha;
  }
  public static class interpolator {
    public static final int btn_checkbox=mi.rjava.R.interpolator.btn_checkbox;
    public static final int toolbar_logo=mi.rjava.R.interpolator.toolbar_logo;
  }
  public static class layout {
    public static final int[] widget_appcompat_dark=mi.rjava.R.layout.widget_appcompat_dark;
  }
}
`,
			expectedRootRJava: `package mi.rjava;
public class R {
  public static class integer {
    public static int cancel_button_image_alpha=0;
  }
  public static class interpolator {
    public static int btn_checkbox=0;
    public static int toolbar_logo=0;
  }
  public static class layout {
    public static int[] widget_appcompat_dark=null;
  }
}
`,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var rJavaBuffer bytes.Buffer
			var rootRJavaBuffer bytes.Buffer
			if err := writeRJavas(&rJavaBuffer, &rootRJavaBuffer, tc.resMap, tc.pkg, tc.rootPackage); err != nil {
				t.Fatalf("writeRJavas(%v, %s, %s) unexpected error: %v", tc.resMap, tc.pkg, tc.rootPackage, err)
			}
			if diff := cmp.Diff(tc.expectedRJava, rJavaBuffer.String()); diff != "" {
				t.Errorf("writeRJavas(%v, %s, %s) returned diff for R.java (-want, +got):\n%v", tc.resMap, tc.pkg, tc.rootPackage, diff)
			}
			if diff := cmp.Diff(tc.expectedRootRJava, rootRJavaBuffer.String()); diff != "" {
				t.Errorf("writeRJavas(%v, %s, %s) returned diff for root R.java(-want, +got):\n%v", tc.resMap, tc.pkg, tc.rootPackage, diff)
			}
		})
	}

}

func TestHasReservedKeywords(t *testing.T) {
	tests := []struct {
		name     string
		pkg      string
		expected bool
	}{
		{
			name:     "valid package",
			pkg:      "com.google.android.apps.sampleapp.lib",
			expected: false,
		},
		{
			name:     "valid package",
			pkg:      "com.google.android.static.sampleapp.lib",
			expected: true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			pkgParts := strings.Split(tc.pkg, ".")
			invalid := hasJavaReservedWord(pkgParts)
			if invalid != tc.expected {
				t.Errorf("hasJavaReservedWord(%v) returned %v, want %v", pkgParts, invalid, tc.expected)
			}
		})
	}

}
