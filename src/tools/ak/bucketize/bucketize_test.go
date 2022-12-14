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

package bucketize

import (
	"bytes"
	"context"
	"encoding/xml"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path"
	"reflect"
	"strings"
	"testing"

	"src/common/golang/shard"
	"src/common/golang/walk"
	"src/tools/ak/res/res"
)

func TestNormalizeResPaths(t *testing.T) {
	// Create a temporary directory to house the fake workspace.
	tmp, err := ioutil.TempDir("", "")
	if err != nil {
		t.Fatalf("Can't make temp directory: %v", err)
	}
	defer os.RemoveAll(tmp)

	var resPaths []string
	fp1 := path.Join(tmp, "foo")
	_, err = os.Create(fp1)
	if err != nil {
		t.Fatalf("Got error while trying to create %s: %v", fp1, err)
	}
	resPaths = append(resPaths, fp1)

	dp1 := path.Join(tmp, "bar", "baz", "qux")
	if err != os.MkdirAll(dp1, 0777) {
		t.Fatalf("Got error while trying to create %s: %v", dp1, err)
	}
	resPaths = append(resPaths, dp1)

	// Create a file nested in the directory that is passed in as a resPath. This file will get
	// injected between fp1 and fp3 because the directory is defined in the middle. Hence,
	// files added to the directory will appear between fp1 and fp3. This behavior is intended.
	fInDP1 := path.Join(dp1, "quux")
	_, err = os.Create(fInDP1)
	if err != nil {
		t.Fatalf("Got error while trying to create %s: %v", fInDP1, err)
	}

	fp3 := path.Join(tmp, "bar", "corge")
	_, err = os.Create(fp3)
	if err != nil {
		t.Fatalf("Got error while trying to create %s: %v", fp3, err)
	}
	resPaths = append(resPaths, fp3)

	gotFiles, err := walk.Files(resPaths)
	if err != nil {
		t.Fatalf("Got error getting the resource paths: %v", err)
	}
	gotFileIdxs := make(map[string]int)
	for i, gotFile := range gotFiles {
		gotFileIdxs[gotFile] = i
	}

	wantFiles := []string{fp1, fInDP1, fp3}
	if !reflect.DeepEqual(gotFiles, wantFiles) {
		t.Errorf("DeepEqual(\n%#v\n,\n%#v\n): returned false", gotFiles, wantFiles)
	}

	wantFileIdxs := map[string]int{fp1: 0, fInDP1: 1, fp3: 2}
	if !reflect.DeepEqual(gotFileIdxs, wantFileIdxs) {
		t.Errorf("DeepEqual(\n%#v\n,\n%#v\n): returned false", gotFileIdxs, wantFileIdxs)
	}
}

func TestArchiverWithPartitionSession(t *testing.T) {
	order := make(map[string]int)
	ps, err := makePartitionSession(map[res.Type][]io.Writer{}, shard.FNV, order)
	if err != nil {
		t.Fatalf("MakePartitionSesion got err: %v", err)
	}
	if _, err := makeArchiver([]string{}, ps); err != nil {
		t.Errorf("MakeArchiver got err: %v", err)
	}
}

func TestArchiveNoValues(t *testing.T) {
	ctx, cxlFn := context.WithCancel(context.Background())
	defer cxlFn()
	a, err := makeArchiver([]string{}, &mockPartitioner{})
	if err != nil {
		t.Fatalf("MakeArchiver got error: %v", err)
	}
	a.Archive(ctx)
}

func TestInternalArchive(t *testing.T) {
	tcs := []struct {
		name    string
		p       Partitioner
		pis     []*res.PathInfo
		vrs     []*res.ValuesResource
		ras     []ResourcesAttribute
		errs    []error
		wantErr bool
	}{
		{
			name: "MultipleResPathInfosAndValuesResources",
			p:    &mockPartitioner{},
			pis:  []*res.PathInfo{{Path: "foo"}},
			vrs: []*res.ValuesResource{
				{Src: &res.PathInfo{Path: "bar"}},
				{Src: &res.PathInfo{Path: "baz"}},
			},
			errs: []error{},
		},
		{
			name: "NoValues",
			p:    &mockPartitioner{},
			pis:  []*res.PathInfo{},
			vrs:  []*res.ValuesResource{},
			errs: []error{},
		},
		{
			name:    "ErrorOccurred",
			p:       &mockPartitioner{},
			pis:     []*res.PathInfo{{Path: "foo"}},
			vrs:     []*res.ValuesResource{},
			errs:    []error{fmt.Errorf("failure")},
			wantErr: true,
		},
	}

	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			piC := make(chan *res.PathInfo)
			go func() {
				defer close(piC)
				for _, pi := range tc.pis {
					piC <- pi
				}
			}()
			vrC := make(chan *res.ValuesResource)
			go func() {
				defer close(vrC)
				for _, vr := range tc.vrs {
					vrC <- vr
				}
			}()
			raC := make(chan *ResourcesAttribute)
			go func() {
				defer close(raC)
				for _, ra := range tc.ras {
					nra := new(ResourcesAttribute)
					*nra = ra
					raC <- nra
				}
			}()
			errC := make(chan error)
			go func() {
				defer close(errC)
				for _, err := range tc.errs {
					errC <- err
				}
			}()
			a, err := makeArchiver([]string{}, tc.p)
			if err != nil {
				t.Errorf("MakeArchiver got error: %v", err)
				return
			}
			ctx, cxlFn := context.WithCancel(context.Background())
			defer cxlFn()
			if err := a.archive(ctx, piC, vrC, raC, errC); err != nil {
				if !tc.wantErr {
					t.Errorf("archive got unexpected error: %v", err)
				}
				return
			}
		})
	}
}

func TestSyncParseReader(t *testing.T) {
	tcs := []struct {
		name    string
		pi      *res.PathInfo
		content *bytes.Buffer
		want    map[string]string
		wantErr bool
	}{
		{
			name: "SingleResourcesBlock",
			pi:   &res.PathInfo{},
			content: bytes.NewBufferString(`<resources>
				<string name="introduction">hello world</string>
				<string name="foo">bar</string>
				<attr name="baz" format="reference|color"></attr>
			</resources>`),
			want: map[string]string{
				"introduction-string": "<string name=\"introduction\">hello world</string>",
				"foo-string":          "<string name=\"foo\">bar</string>",
				"baz-attr":            "<attr name=\"baz\" format=\"reference|color\"></attr>",
			},
		},
		{
			name: "MultipleResourcesBlocks",
			pi:   &res.PathInfo{},
			content: bytes.NewBufferString(`<resources>
				<string name="introduction">hello world</string>
				<string name="foo">bar</string>
			</resources>
			<!--
			Subsequent resources sections are ignored, hence the "qux" item will not
			materialize in the parsed values.
			-->
			<resources>
				<item name="qux" type="integer">23</item>
			</resources>`),
			want: map[string]string{
				"introduction-string": "<string name=\"introduction\">hello world</string>",
				"foo-string":          "<string name=\"foo\">bar</string>",
			},
		},
		{
			name: "NamespacedResourcesBlock",
			pi:   &res.PathInfo{},
			content: bytes.NewBufferString(`<resources xmlns:foo="bar">
			        <string name="namespaced"><foo:bar>hello</foo:bar> world</string>
			</resources>`),
			want: map[string]string{
				"resource_attribute-xmlns:foo": "bar",
				"namespaced-string":            "<string name=\"namespaced\"><foo:bar>hello</foo:bar> world</string>",
			},
		},
		{
			name:    "DeclareStyleable",
			pi:      &res.PathInfo{},
			content: bytes.NewBufferString("<resources><declare-styleable name=\"foo\"><attr name=\"bar\">baz</attr></declare-styleable></resources>"),
			want: map[string]string{
				"foo-styleable": "<declare-styleable name=\"foo\"><attr name=\"bar\">baz</attr></declare-styleable>",
				"bar-attr":      "<attr name=\"bar\">baz</attr>",
			},
		},
		{
			name:    "NamespacedStyleableBlock",
			pi:      &res.PathInfo{},
			content: bytes.NewBufferString("<resources xmlns:zoo=\"zoo\"><declare-styleable name=\"foo\"><attr name=\"bar\" zoo:qux=\"rux\">baz</attr></declare-styleable></resources>"),
			want: map[string]string{
				"resource_attribute-xmlns:zoo": "zoo",
				"foo-styleable":                "<declare-styleable name=\"foo\"><attr name=\"bar\" zoo:qux=\"rux\">baz</attr></declare-styleable>",
				"bar-attr":                     "<attr name=\"bar\" zoo:qux=\"rux\">baz</attr>",
			},
		},
		{
			name: "PluralsStringArrayOutputToStringToo",
			pi:   &res.PathInfo{},
			content: bytes.NewBufferString(`<resources>
				<string-array name="foo"><item>bar</item><item>baz</item></string-array>
				<plurals name="corge"><item quantity="one">qux</item><item quantity="other">quux</item></plurals>
			</resources>`),
			want: map[string]string{
				"foo-array":     "<string-array name=\"foo\"><item>bar</item><item>baz</item></string-array>",
				"corge-plurals": "<plurals name=\"corge\"><item quantity=\"one\">qux</item><item quantity=\"other\">quux</item></plurals>",
			},
		},
		{
			name: "AttrWithFlagOrEnumChildren",
			pi:   &res.PathInfo{},
			content: bytes.NewBufferString(`<resources>
				<attr name="foo"><enum name="bar" value="0" /><enum name="baz" value="10" /></attr>
				<attr name="qux"><flag name="quux" value="0x4" /></attr>
			</resources>`),
			want: map[string]string{
				"foo-attr": "<attr name=\"foo\"><enum name=\"bar\" value=\"0\"></enum><enum name=\"baz\" value=\"10\"></enum></attr>",
				"qux-attr": "<attr name=\"qux\"><flag name=\"quux\" value=\"0x4\"></flag></attr>",
			},
		},
		{
			name: "Style",
			pi:   &res.PathInfo{},
			content: bytes.NewBufferString(`<resources>
				<style name="foo"><item>bar</item><item>baz</item></style>
			</resources>`),
			want: map[string]string{
				"foo-style": "<style name=\"foo\"><item>bar</item><item>baz</item></style>",
			},
		},
		{
			name: "ArraysGoToStingAndInteger",
			pi:   &res.PathInfo{},
			content: bytes.NewBufferString(`<resources>
				<array name="foo"><item>bar</item><item>1</item></array>
			</resources>`),
			want: map[string]string{
				"foo-array": "<array name=\"foo\"><item>bar</item><item>1</item></array>",
			},
		},
		{
			name:    "NoContent",
			pi:      &res.PathInfo{},
			content: &bytes.Buffer{},
			want:    map[string]string{},
		},
		{
			name:    "EmptyResources",
			pi:      &res.PathInfo{},
			content: bytes.NewBufferString("<resources></resources>"),
			want:    map[string]string{},
		},
		{
			name: "IgnoredContent",
			pi:   &res.PathInfo{},
			content: bytes.NewBufferString(`
			<!--ignore my comment-->
			<ignore_tag />
			ignore random string.
			<resources>
				<!--ignore this comment too-->
				<attr name="foo">bar<baz>qux</baz></attr>
				ignore this random string too.
				<!-- following are a list of ignored tags -->
				<eat-comment />
				<skip />
			</resources>`),
			want: map[string]string{
				"foo-attr": "<attr name=\"foo\">bar<baz>qux</baz></attr>",
			},
		},
		{
			name:    "TagMissingNameAttribute",
			pi:      &res.PathInfo{},
			content: bytes.NewBufferString(`<resources><string>MissingNameAttr</string></resources>`),
			wantErr: true,
		},
		{
			name:    "ItemTagMissingTypeAttribute",
			pi:      &res.PathInfo{},
			content: bytes.NewBufferString(`<resources><item name="MissingTypeAttr">bar</item></resources>`),
			wantErr: true,
		},
		{
			name:    "ItemTagUnknownTypeAttribute",
			pi:      &res.PathInfo{},
			content: bytes.NewBufferString(`<resources><item name="UnknownType" type="foo" /></resources>`),
			wantErr: true,
		},
		{
			name:    "UnhandledTag",
			pi:      &res.PathInfo{},
			content: bytes.NewBufferString(`<resources><foo name="bar"/></resources>`),
			wantErr: true,
		},
		{
			name:    "MalFormedXml_OpenResourcesTag",
			pi:      &res.PathInfo{},
			content: bytes.NewBufferString(`<resources>`),
			wantErr: true,
		},
		{
			name:    "MalFormedXml_Unabalanced",
			pi:      &res.PathInfo{},
			content: bytes.NewBufferString(`<resources><attr name="unbalanced"><b></attr></resources>`),
			wantErr: true,
		},
		{
			name:    "NamespaceUsedWithoutNamespaceDefinition",
			pi:      &res.PathInfo{},
			content: bytes.NewBufferString(`<resources><string name="ohno"><bad:b>Oh no!</bad:b></string></resources>`),
			wantErr: true,
		},
		{
			// Verify parent Encoder is properly shadowing the xml file.
			name: "NamespaceUsedOutsideOfDefinition",
			pi:   &res.PathInfo{},
			content: bytes.NewBufferString(`
			<resources>
			  <string name="foo" xmlns:bar="baz">qux</string>
			  <string name="ohno"><foo:b>Oh no!</foo:b></string>
			</resources>`),
			wantErr: true,
		},
	}
	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			ctx, cxlFn := context.WithCancel(context.Background())
			defer cxlFn()
			vrC := make(chan *res.ValuesResource)
			raC := make(chan *ResourcesAttribute)
			errC := make(chan error)
			go func() {
				defer close(vrC)
				defer close(raC)
				defer close(errC)
				syncParseReader(ctx, tc.pi, xml.NewDecoder(tc.content), vrC, raC, errC)
			}()
			got := make(map[string]string)
			errMs := make([]string, 0)
			for errC != nil || vrC != nil {
				select {
				case e, ok := <-errC:
					if !ok {
						errC = nil
					}
					if e != nil {
						errMs = append(errMs, e.Error())
					}
				case ra, ok := <-raC:
					if !ok {
						raC = nil
					}
					if ra != nil {
						a := ra.Attribute
						got[fmt.Sprintf("resource_attribute-%s:%s", a.Name.Space, a.Name.Local)] = a.Value
					}
				case vr, ok := <-vrC:
					if !ok {
						vrC = nil
					}
					if vr != nil {
						got[fmt.Sprintf("%s-%s", vr.N.Name, vr.N.Type.String())] = string(vr.Payload)
					}
				}
			}

			// error handling
			if tc.wantErr {
				if len(errMs) == 0 {
					t.Errorf("syncParseReader expected an error.")
				}
				return
			}
			if len(errMs) > 0 {
				t.Errorf("syncParserReader got unexpected error(s): \n%s", strings.Join(errMs, "\n"))
				return
			}

			if !reflect.DeepEqual(got, tc.want) {
				t.Errorf("DeepEqual(\n%#v\n,\n%#v\n): returned false", got, tc.want)
			}
		})
	}
}

// mockPartitioner is a Partitioner mock used for testing.
type mockPartitioner struct {
	strPI []res.PathInfo
	cvVR  []res.ValuesResource
	ra    []*ResourcesAttribute
}

func (mp *mockPartitioner) Close() error {
	return nil
}

func (mp *mockPartitioner) CollectPathResource(src res.PathInfo) {
	mp.strPI = append(mp.strPI, src)
}

func (mp *mockPartitioner) CollectValues(vr *res.ValuesResource) error {
	mp.cvVR = append(mp.cvVR, res.ValuesResource{vr.Src, vr.N, vr.Payload})
	return nil
}

func (mp *mockPartitioner) CollectResourcesAttribute(ra *ResourcesAttribute) {
	mp.ra = append(mp.ra, ra)
}
