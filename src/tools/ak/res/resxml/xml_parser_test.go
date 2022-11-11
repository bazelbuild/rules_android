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

package resxml

import (
	"bytes"
	"context"
	"encoding/xml"
	"io"
	"reflect"
	"testing"

	"src/tools/ak/res/respipe/respipe"
)

const (
	doc = `
		<Person>
			<FullName>Grace R. Emlin</FullName>
			<Company>Example Inc.</Company>
			<Email where="home">
				<Addr>gre@example.com</Addr>
			</Email>
			<City>Hanga Rao<Street>1234 Main St.</Street>RandomText</City>
			<Email where='work'>
				<Addr>gre@work.com</Addr>
			</Email>
			<Group>
				<Value>Friends</Value>
				<Value>Squash</Value>
			</Group>
			<State>Easter Island</State>
		</Person>
	`
)

func TestForwardChildren(t *testing.T) {
	ctx, cancel := context.WithCancel(respipe.PrefixErr(context.Background(), "test doc: "))
	defer cancel()
	xmlC, errC := StreamDoc(ctx, bytes.NewBufferString(doc))
	xe, ok := ConsumeUntil(xml.Name{Local: "City"}, xmlC)
	if !ok {
		t.Fatalf("Expected to find: %s in %s", xml.Name{Local: "City"}, doc)
	}
	childC := ForwardChildren(ctx, xe, xmlC)
	wantEvents := []XMLEvent{
		{
			Token: xml.CharData("Hanga Rao"),
		},
		{
			Token: xml.StartElement{Name: xml.Name{Local: "Street"}, Attr: []xml.Attr{}},
		},
		{
			Token: xml.CharData("1234 Main St."),
		},
		{
			Token: xml.EndElement{Name: xml.Name{Local: "Street"}},
		},
		{
			Token: xml.CharData("RandomText"),
		},
	}
	var gotEvents []XMLEvent
	for childC != nil || errC != nil {
		select {
		case xe, ok := <-childC:
			if !ok {
				childC = nil
				cancel()
				continue
			}
			xe.Offset = 0
			gotEvents = append(gotEvents, xe)
		case e, ok := <-errC:
			if !ok {
				errC = nil
				continue
			}
			t.Errorf("unexpected error: %v", e)
		}
	}

	if !reflect.DeepEqual(wantEvents, gotEvents) {
		t.Errorf("Got children: %#v wanted: %#v", gotEvents, wantEvents)
	}

}

func TestAttrs(t *testing.T) {
	tests := []struct {
		arg  XMLEvent
		want []xml.Attr
	}{
		{
			XMLEvent{
				Token: xml.StartElement{
					Attr: []xml.Attr{
						{
							Name:  xml.Name{Local: "dog"},
							Value: "shepard",
						},
						{
							Name:  xml.Name{Local: "cat"},
							Value: "cheshire",
						},
					},
				},
			},
			[]xml.Attr{
				{
					Name:  xml.Name{Local: "dog"},
					Value: "shepard",
				},
				{
					Name:  xml.Name{Local: "cat"},
					Value: "cheshire",
				},
			},
		},
		{
			XMLEvent{Token: xml.StartElement{}},
			[]xml.Attr(nil),
		},
		{
			XMLEvent{Token: xml.CharData("foo")},
			[]xml.Attr(nil),
		},
	}

	for _, tc := range tests {
		got := Attrs(tc.arg)
		if !reflect.DeepEqual(got, tc.want) {
			t.Errorf("Attrs(%#v): %#v wanted %#v", tc.arg, got, tc.want)
		}
	}
}

func TestConsumeUntil(t *testing.T) {
	ctx, cancel := context.WithCancel(respipe.PrefixErr(context.Background(), "test doc: "))
	defer cancel()
	xmlC, errC := StreamDoc(ctx, bytes.NewBufferString(doc))

	xe, ok := ConsumeUntil(xml.Name{Local: "Email"}, xmlC)
	if !ok {
		t.Fatalf("Expected to find: %s in %s", xml.Name{Local: "Email"}, doc)
	}
	if se, ok := xe.Token.(xml.StartElement); ok {
		want := []xml.Attr{{xml.Name{Local: "where"}, "home"}}
		if !reflect.DeepEqual(want, se.Attr) {
			t.Errorf("Got attr: %v wanted: %v", se.Attr, want)
		}
	} else {
		t.Fatalf("Got: %v Expected to stop on a start element", xe)
	}
	xe, ok = ConsumeUntil(xml.Name{Local: "Email"}, xmlC)
	if !ok {
		t.Fatalf("Expected to find: %s in %s", xml.Name{Local: "Email"}, doc)
	}
	if se, ok := xe.Token.(xml.StartElement); ok {
		want := []xml.Attr{{xml.Name{Local: "where"}, "work"}}
		if !reflect.DeepEqual(want, se.Attr) {
			t.Errorf("Got attr: %v wanted: %v", se.Attr, want)
		}
	} else {
		t.Fatalf("Got: %v Expected to stop on a start element", xe)
	}
	xe, ok = ConsumeUntil(xml.Name{Local: "Email"}, xmlC)
	if ok {
		t.Fatalf("Expected no more nodes with: %v got: %v in doc: %s", xml.Name{Local: "Email"}, xe, doc)
	}
	e, ok := <-errC
	if ok {
		t.Fatalf("Expected no errors during parse: %v", e)
	}
}

func TestStreamDoc(t *testing.T) {
	dec := xml.NewDecoder(bytes.NewBufferString(doc))
	var events []XMLEvent
	for {
		tok, err := dec.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatalf("Unexpected xml parse failure: %v", err)
		}
		events = append(events, XMLEvent{xml.CopyToken(tok), dec.InputOffset()})
	}
	ctx, cancel := context.WithCancel(respipe.PrefixErr(context.Background(), "test doc: "))
	defer cancel()
	xmlC, errC := StreamDoc(ctx, bytes.NewBufferString(doc))
	var got []XMLEvent
	for xmlC != nil || errC != nil {
		select {
		case e, ok := <-errC:
			if !ok {
				errC = nil
				continue
			}
			t.Errorf("Unexpected error: %v", e)
		case xe, ok := <-xmlC:
			if !ok {
				xmlC = nil
				continue
			}
			got = append(got, xe)
		}
	}
	if !reflect.DeepEqual(events, got) {
		t.Errorf("StreamDoc() got: %v wanted: %v", got, events)
	}

}
