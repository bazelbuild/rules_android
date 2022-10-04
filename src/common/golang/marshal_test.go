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

package xml2

import (
	"bufio"
	"bytes"
	"encoding/xml"
	"io"
	"strings"
	"testing"
)

func TestEncoderEncodeToken(t *testing.T) {
	tests := []struct {
		name    string
		in      string
		want    string
		wantErr string
	}{
		{
			name: "xmlnsPrefixForElement",
			in:   "<foo:bar xmlns:foo=\"baz\"></foo:bar>",
			want: "<foo:bar xmlns:foo=\"baz\"></foo:bar>",
		},
		{
			name: "xmlnsPrefixForAttribute",
			in:   "<foo bar:baz=\"qux\" xmlns:bar=\"quux\"></foo>",
			want: "<foo bar:baz=\"qux\" xmlns:bar=\"quux\"></foo>",
		},
		{
			name: "defaultXmlnsAttribute",
			in:   "<foo xmlns=\"bar\"></foo>",
			want: "<foo xmlns=\"bar\"></foo>",
		},
		{
			// The return value of Decoder.Token() makes it
			// impossible for a decode then encode of an xml file
			// be isomorphic. This is mainly due to the fact that
			// xml.Name.Space contains the uri, and xml.Name does
			// not store the prefix. Instead, make sure that the
			// behavior remains consistent.
			//
			// That is, the last prefix defined for the space is the
			// one applied when encoding the token.
			name: "multipleDefsXmlnsPrefixesSameUri",
			in: `
<foo xmlns:bar="bar">
  <bar:baz xmlns:qux="bar">
    <qux:quux></qux:quux>
  </bar:baz>
</foo>`,
			want: `
<foo xmlns:bar="bar">
  <qux:baz xmlns:qux="bar">
    <qux:quux></qux:quux>
  </qux:baz>
</foo>`,
		},
		{
			name:    "xmlnsPrefixUsedOnElementButNotDefined",
			in:      "<foo:bar></foo:bar>",
			wantErr: "unknown namespace: foo",
		},
		{
			name:    "xmlnsPrefixUsedOnAttrButNotDefined",
			in:      "<foo bar:baz=\"qux\"></foo>",
			wantErr: "unknown namespace: bar",
		},
		{
			name: "xmlnsPrefixUsedOutsideOfDefiningTag",
			in: `
<foo xmlns:bar="baz" bar:qux="quux">corge</foo>
<grault bar:garply="waldo"></grault>`,
			wantErr: "unknown namespace: bar",
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			var b bytes.Buffer
			e := NewEncoder(bufio.NewWriter(&b))
			d := xml.NewDecoder(strings.NewReader(test.in))
			for {
				tkn, err := d.Token()
				if err != nil {
					if err == io.EOF {
						break
					}
					t.Fatalf("Unexpected error got: %v while reading: %s", err, test.in)
				}
				if err := e.EncodeToken(tkn); err != nil {
					if test.wantErr != "" && strings.Contains(err.Error(), test.wantErr) {
						// Do nothing, error is expected.
					} else {
						t.Errorf("Unexpected error during encode: %v", err)
					}
					return
				}
			}
			e.Flush()
			if b.String() != test.want {
				t.Errorf("got: <%s> expected: <%s>", b.String(), test.want)
			}
		})
	}
}

func TestChildEncoder(t *testing.T) {
	// Setup the parent Encoder with the namespace "bar".
	d := xml.NewDecoder(strings.NewReader("<foo xmlns:bar=\"bar\"><bar:baz>Hello World</bar:baz></foo>"))
	tkn, err := d.Token()
	if err != nil {
		t.Fatalf("Error occurred during decoding, got: %v", err)
	}
	parentEnc := NewEncoder(&bytes.Buffer{})
	if err := parentEnc.EncodeToken(tkn); err != nil {
		t.Fatalf("Error occurred while the parent encoder was encoding token %q got: %v", tkn, err)
	}

	// Without instantiating the Encoder as a child, the "bar" namespace will be unknown and cause an
	// error to occur when trying to encode the "bar" namespaced element "<bar:baz>".
	tkn, err = d.Token()
	if err != nil {
		t.Fatalf("Error occurred during decoding, got: %v", err)
	}
	b := &bytes.Buffer{}
	childEnc := ChildEncoder(b, parentEnc)
	if err := childEnc.EncodeToken(tkn); err != nil {
		t.Fatalf("Error occurred while the child encoder was encoding token %q got: %v", tkn, err)
	}
	childEnc.Flush()

	// Verify that the token is not mangled.
	if want := "<bar:baz>"; b.String() != want {
		t.Errorf("Error, got %q, wanted %q", b.String(), want)
	}
}
