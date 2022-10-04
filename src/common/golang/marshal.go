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

// Package xml2 provides drop-in replacement functionality for encoding/xml.
//
// There are existing issues with the encoding/xml package that affect AK tools.
//
// xml2.Encoder:
//
// The current encoding/xml Encoder has several issues around xml namespacing
// that makes the output produced by it incompatible with AAPT.
//
// * Tracked here: https://golang.org/issue/7535
//
// The xml2.Encoder.EncodeToken verifies the validity of namespaces and encodes
// them. For everything else, xml2.Encoder will fallback to the xml.Encoder.
package xml2

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"log"
)

const xmlNS = "xmlns"

// Encoder is an xml encoder which behaves much like the encoding/xml Encoder.
type Encoder struct {
	*xml.Encoder
	p         printer
	prefixURI map[string]string
	state     []state
	uriPrefix *uriPrefixMap
}

// ChildEncoder returns an encoder whose state is copied the given parent Encoder and writes to w.
func ChildEncoder(w io.Writer, parent *Encoder) *Encoder {
	e := NewEncoder(w)
	for k, v := range parent.prefixURI {
		e.prefixURI[k] = v
	}
	for k, v := range parent.uriPrefix.up {
		e.uriPrefix.up[k] = make([]string, len(v))
		copy(e.uriPrefix.up[k], v)
	}
	return e
}

// NewEncoder returns a new encoder that writes to w.
func NewEncoder(w io.Writer) *Encoder {
	e := &Encoder{
		Encoder:   xml.NewEncoder(w),
		p:         printer{Writer: w},
		prefixURI: make(map[string]string),
		uriPrefix: &uriPrefixMap{up: make(map[string][]string)},
	}
	return e
}

// EncodeToken behaves almost the same as encoding/xml.Encoder.EncodeToken
// but deals with StartElement and EndElement differently.
func (enc *Encoder) EncodeToken(t xml.Token) error {
	switch t := t.(type) {
	case xml.StartElement:
		enc.Encoder.Flush() // Need to flush the wrapped encoder before we write.
		if err := enc.writeStart(&t); err != nil {
			return err
		}
	case xml.EndElement:
		enc.Encoder.Flush() // Need to flush the wrapped encoder before we write.
		if err := enc.writeEnd(t.Name); err != nil {
			return err
		}
	default:
		// Delegate to the embedded encoder for everything else.
		return enc.Encoder.EncodeToken(t)
	}
	return nil
}

func (enc *Encoder) writeStart(start *xml.StartElement) error {
	if start.Name.Local == "" {
		return fmt.Errorf("start tag with no name")
	}
	enc.setUpState(start)

	// Begin creating the start tag.
	var st bytes.Buffer
	st.WriteByte('<')
	n, err := enc.translateName(start.Name)
	if err != nil {
		return fmt.Errorf("translating start tag name %q failed, got: %v", start.Name.Local, err)
	}
	st.Write(n)
	for _, attr := range start.Attr {
		name := attr.Name
		if name.Local == "" {
			continue
		}
		st.WriteByte(' ')
		n, err := enc.translateName(attr.Name)
		if err != nil {
			return fmt.Errorf("translating attribute name %q failed, got: %v", start.Name.Local, err)
		}
		st.Write(n)
		st.WriteString(`="`)
		xml.EscapeText(&st, []byte(attr.Value))
		st.WriteByte('"')
	}
	st.WriteByte('>')

	enc.p.writeIndent(1)
	enc.p.Write(st.Bytes())
	return nil
}

func (enc *Encoder) writeEnd(name xml.Name) error {
	if name.Local == "" {
		return fmt.Errorf("end tag with no name")
	}
	n, err := enc.translateName(name)
	if err != nil {
		return fmt.Errorf("translating end tag name %q failed, got: %v", name.Local, err)
	}
	sn := enc.tearDownState()
	if sn == nil || name.Local != sn.Local && name.Space != sn.Space {
		return fmt.Errorf("tags are unbalanced, got: %v, wanted: %v", name, sn)
	}

	// Begin creating the end tag
	var et bytes.Buffer
	et.WriteString("</")
	et.Write(n)
	et.WriteByte('>')

	enc.p.writeIndent(-1)
	enc.p.Write(et.Bytes())
	return nil
}

func (enc *Encoder) setUpState(start *xml.StartElement) {
	enc.state = append(enc.state, element{n: &start.Name}) // Store start element to verify balanced close tags.
	// Track attrs that affect the state of the xml (e.g. xmlns, xmlns:foo).
	for _, attr := range start.Attr {
		// push any xmlns type attrs as xml namespaces are valid within the tag they are declared in, and onward.
		if attr.Name.Space == "xmlns" || attr.Name.Local == "xmlns" {
			prefix := attr.Name.Local
			if attr.Name.Local == "xmlns" {
				prefix = "" // Default xml namespace is being set.
			}
			// Store the previous state, to be restored when exiting the tag.
			enc.state = append(enc.state, xmlns{prefix: prefix, uri: enc.prefixURI[prefix]})
			enc.prefixURI[prefix] = attr.Value
			enc.uriPrefix.put(attr.Value, prefix)
		}
	}
}

func (enc *Encoder) tearDownState() *xml.Name {
	// Unwind the state setup on start element.
	for len(enc.state) > 0 {
		s := enc.state[len(enc.state)-1]
		enc.state = enc.state[:len(enc.state)-1]
		switch s := s.(type) {
		case element:
			// Stop unwinding As soon as an element type is seen and verify that the
			// tags are balanced
			return s.n
		case xmlns:
			if p, ok := enc.uriPrefix.removeLast(enc.prefixURI[s.prefix]); !ok || p != s.prefix {
				// Unexpected error, internal state is corrupt.
				if !ok {
					log.Fatalf("xmlns attribute state corrupt, uri %q does not exist", enc.prefixURI[s.prefix])
				}
				log.Fatalf("xmlns attributes state corrupt, got: %q, wanted: %q", s.prefix, p)
			}
			if s.uri == "" {
				delete(enc.prefixURI, s.prefix)
			} else {
				enc.prefixURI[s.prefix] = s.uri
			}
		}
	}
	return nil
}

func (enc *Encoder) translateName(name xml.Name) ([]byte, error) {
	var n bytes.Buffer
	if name.Space != "" {
		prefix := ""
		if name.Space == xmlNS {
			prefix = xmlNS
		} else if ns, ok := enc.uriPrefix.getLast(name.Space); ok {
			// URI Space is defined in current context, use the namespace.
			prefix = ns
		} else if _, ok := enc.prefixURI[name.Space]; ok {
			// If URI Space is not defined in current context, there is a possibility
			// that the Space is in fact a namespace prefix. If present use it.
			prefix = name.Space
		} else {
			return nil, fmt.Errorf("unknown namespace: %s", name.Space)
		}
		if prefix != "" {
			n.WriteString(prefix)
			n.WriteByte(':')
		}
	}
	n.WriteString(name.Local)
	return n.Bytes(), nil
}

type printer struct {
	io.Writer
	indent     string
	prefix     string
	depth      int
	indentedIn bool
	putNewline bool
}

// writeIndent is directly cribbed from encoding/xml/marshal.go to keep indentation behavior the same.
func (p *printer) writeIndent(depthDelta int) {
	if len(p.prefix) == 0 && len(p.indent) == 0 {
		return
	}
	if depthDelta < 0 {
		p.depth--
		if p.indentedIn {
			p.indentedIn = false
			return
		}
		p.indentedIn = false
	}
	if p.putNewline {
		p.Write([]byte("\n"))
	} else {
		p.putNewline = true
	}
	if len(p.prefix) > 0 {
		p.Write([]byte(p.prefix))
	}
	if len(p.indent) > 0 {
		for i := 0; i < p.depth; i++ {
			p.Write([]byte(p.indent))
		}
	}
	if depthDelta > 0 {
		p.depth++
		p.indentedIn = true
	}

}

// uriPrefixMap is a multimap, mapping a uri to many xml namespace prefixes. The
// difference with this and a a traditional multimap is that, you can only get
// or remove the last prefixed added. This is mainly due to the way xml decoding
// is implemented by the encoding/xml Decoder.
type uriPrefixMap struct {
	up map[string][]string
}

// getLast returns a boolean which signifies if the entry exists and the last
// prefix stored for the given uri.
func (u *uriPrefixMap) getLast(uri string) (string, bool) {
	ps, ok := u.up[uri]
	if !ok {
		return "", ok
	}
	return ps[len(ps)-1], ok
}

func (u *uriPrefixMap) put(uri, prefix string) {
	if _, ok := u.up[uri]; !ok {
		// Though the mapping of url-to-prefix is implemented for a multimap, in practice,
		// there should never be more than a single prefix defined for any given uri within
		// at any point in time in an xml file.
		u.up[uri] = make([]string, 1)
	}
	u.up[uri] = append(u.up[uri], prefix)
}

// removeLast a boolean which signifies if the entry exists and returns the last
// prefix removed for the given uri. If the last entry is removed the key is
// also deleted.
func (u *uriPrefixMap) removeLast(uri string) (string, bool) {
	p, ok := u.getLast(uri)
	if ok {
		if len(u.up[uri]) > 1 {
			u.up[uri] = u.up[uri][:len(u.up[uri])-1]
		} else {
			delete(u.up, uri)
		}
	}
	return p, ok
}

// state stores the state of the xml when a new start element is seen.
type state interface{}

// xml element state entry.
type element struct {
	n *xml.Name
}

// xmlns attribute state entry.
type xmlns struct {
	prefix string
	uri    string
}
