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
	"strings"
	"testing"

	"src/tools/ak/res/res"
	"src/tools/ak/res/respipe/respipe"
	"src/tools/ak/res/resxml/resxml"
)

func TestResValuesParse(t *testing.T) {
	tests := []struct {
		doc       string
		wanted    []string
		wantedErr []string
	}{
		{
			doc: `<resources>
			<integer name='two'>2</integer>
			<string name='embedded_stuff'>hi <b>there</b></string>
			</resources>`,
			wanted: []string{
				"res-auto:integer/two",
				"res-auto:string/embedded_stuff",
			},
		},
		{
			doc: `<resources>
			<fraction name='frac'>12dp</fraction>
			<item type='id' name='foo'/>
      <id name='two'/>
			<bool name='on'>true</bool>
			</resources>`,
			wanted: []string{
				"res-auto:fraction/frac",
				"res-auto:id/foo",
				"res-auto:id/two",
				"res-auto:bool/on",
			},
		},
		{
			doc: `<resources>
			<color name='red'>#fff</color>
			<item name='hundred' type='dimen'>100%</item>
			<attr name="custom">
				<enum name="cars" value="21"/>
				<enum name="planes" value="42"/>
			</attr>
			<eat-comment/>
			<!-- a comment -->
			<attr name='textSize'/>
			</resources>`,
			wanted: []string{
				"res-auto:color/red",
				"res-auto:dimen/hundred",
				"res-auto:id/cars",
				"res-auto:id/planes",
				"res-auto:attr/custom",
				"res-auto:attr/textSize",
			},
		},
		{
			doc: `<resources>
			<attr name='touch'>
				<flag name="tap" value="0"/>
				<flag name="double_tap" value="2"/>
			</attr>
			<integer-array name='empty'>
			</integer-array>
			<integer-array name='five'>
				<item>1</item>
				<item>@integer/two</item>
			</integer-array>
			</resources>`,

			wanted: []string{
				"res-auto:id/tap",
				"res-auto:id/double_tap",
				"res-auto:attr/touch",
				"res-auto:array/empty",
				"res-auto:array/five",
			},
		},
		{

			doc: `<resources>
					<declare-styleable name='absPieChart'>
						<attr name='android:gravity'/>
						<attr name='local' format='string'/>
						<attr name='overlay'>
							<flag name="transparent" value="0"/>
							<flag name="awesome" value="2"/>
						</attr>
					</declare-styleable>
		  	</resources>`,
			wanted: []string{
				"res-auto:attr/local",
				"res-auto:id/transparent",
				"res-auto:id/awesome",
				"res-auto:attr/overlay",
				"res-auto:styleable/absPieChart",
			},
		},
		{
			doc:       `<resources><string>2</string></resources>`,
			wantedErr: []string{"Expected to encounter name attribute"},
		},
	}

	for _, tc := range tests {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		xmlC, xmlErrC := resxml.StreamDoc(ctx, bytes.NewBufferString(tc.doc))
		resC, parseErrC := valuesParse(ctx, xmlC)
		errC := respipe.MergeErrStreams(ctx, []<-chan error{xmlErrC, parseErrC})
		var parsedNames []string
		var errStrs []string
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
				errStrs = append(errStrs, e.Error())
			}

		}

		if !reflect.DeepEqual(parsedNames, tc.wanted) {
			t.Errorf("valuesParse of: %s got: %s wanted: %s", tc.doc, parsedNames, tc.wanted)
		}
		if len(errStrs) != len(tc.wantedErr) {
			t.Errorf("%s: unexpected amount of errs: %v wanted: %v", tc.doc, errStrs, tc.wantedErr)
			continue
		}
		for i, e := range errStrs {
			if !strings.Contains(e, tc.wantedErr[i]) {
				t.Errorf("doc: %q got err: %s should contain: %s", tc.doc, e, tc.wantedErr[i])
			}
		}
	}
}
