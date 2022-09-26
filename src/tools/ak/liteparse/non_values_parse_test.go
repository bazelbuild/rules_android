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

package liteparse

import (
	"bytes"
	"context"
	"reflect"
	"testing"

	"src/tools/ak/res/res"
	"src/tools/ak/res/respipe/respipe"
	"src/tools/ak/res/resxml/resxml"
)

func TestResNonValuesParse(t *testing.T) {
	tests := []struct {
		doc    string
		wanted []string
	}{
		{
			`<?xml version="1.0" encoding="utf-8"?>
			<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
				android:layout_width="match_parent">
				<!-- a comment -->
				<TextView android:id="@+id/new_tv" android:layout_height="match_parent"/>
				<LinearLayout android:id="@+id/bad_layouts" android:layout_height="match_parent">
					<Something myAttr="@+id/id_here_too"/>
				<LinearLayout android:id="@+id/really_bad_layouts"/>
			</LinearLayout>

			</LinearLayout>
			`,
			[]string{
				"res-auto:id/new_tv",
				"res-auto:id/bad_layouts",
				"res-auto:id/id_here_too",
				"res-auto:id/really_bad_layouts",
			},
		},
	}

	for _, tc := range tests {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		xmlC, xmlErrC := resxml.StreamDoc(ctx, bytes.NewBufferString(tc.doc))
		resC, parseErrC := nonValuesParse(ctx, xmlC)
		errC := respipe.MergeErrStreams(ctx, []<-chan error{xmlErrC, parseErrC})
		var parsedNames []string
		for resC != nil || errC != nil {
			select {
			case r, ok := <-resC:
				if !ok {
					resC = nil
					continue
				}
				pn, err := res.ParseName(r.GetName(), res.Type(r.ResourceType))
				if err != nil {
					t.Errorf("res.ParseName(%s, %v) unexpected err: %v", r.GetName(), r.ResourceType, err)
				}
				parsedNames = append(parsedNames, pn.String())
			case e, ok := <-errC:
				if !ok {
					errC = nil
					continue
				}
				t.Errorf("unexpected error: %v", e)
			}
		}

		if !reflect.DeepEqual(parsedNames, tc.wanted) {
			t.Errorf("nonValuesParse of: %s got: %s wanted: %s", tc.doc, parsedNames, tc.wanted)
		}
	}

}
