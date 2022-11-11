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

// Package resxml contains common functions to extract information from xml files and feed that information into the resource processing pipeline.
package resxml

import (
	"context"
	"encoding/xml"
	"io"

	"src/tools/ak/res/respipe/respipe"
)

// XMLEvent wraps an XMLToken and the Offset at which it was encountered.
type XMLEvent struct {
	Token  xml.Token
	Offset int64
}

// ConsumeUntil takes xmlEvents from the provided chan and discards them until it finds a StartEvent which matches the provided name. If the channel is exhausted, false is returned.
func ConsumeUntil(name xml.Name, xmlC <-chan XMLEvent) (XMLEvent, bool) {
	for xe := range xmlC {
		if se, ok := xe.Token.(xml.StartElement); ok {
			if SloppyMatches(name, se.Name) {
				return xe, true
			}
		}
	}
	return XMLEvent{}, false
}

// ForwardChildren takes the provided StartElement and a channel of XMLEvents and forwards that all events onto the returned XMLEvent channel until the matching EndElement to start is encountered.
func ForwardChildren(ctx context.Context, start XMLEvent, xmlC <-chan XMLEvent) <-chan XMLEvent {
	eventC := make(chan XMLEvent, 1)
	se := start.Token.(xml.StartElement)
	go func() {
		defer close(eventC)
		count := 1
		for xe := range xmlC {
			if e, ok := xe.Token.(xml.StartElement); ok {
				if StrictMatches(e.Name, se.Name) {
					count++
				}
			}
			if e, ok := xe.Token.(xml.EndElement); ok {
				if StrictMatches(e.Name, se.Name) {
					count--
				}
				if count == 0 {
					return
				}
			}
			if !SendXML(ctx, eventC, xe) {
				return
			}
		}
	}()
	return eventC

}

// StrictMatches considers xml.Names equal if both their space and name matches.
func StrictMatches(n1, n2 xml.Name) bool {
	return n1.Local == n2.Local && n1.Space == n2.Space
}

// SloppyMatches ignores xml.Name Space attributes unless both names specify Space. Otherwise
// only the Local attribute is used for matching.
func SloppyMatches(n1, n2 xml.Name) bool {
	if n1.Space != "" && n2.Space != "" {
		return StrictMatches(n1, n2)
	}
	return n1.Local == n2.Local
}

// StreamDoc parses the provided doc and forwards all xml tokens to the returned XMLEvent chan.
func StreamDoc(ctx context.Context, doc io.Reader) (<-chan XMLEvent, <-chan error) {
	eventC := make(chan XMLEvent)
	errC := make(chan error)
	go func() {
		defer close(eventC)
		defer close(errC)
		decoder := xml.NewDecoder(doc)
		// Turns off unknown entities check. Would otherwise fail on resources
		// using non-standard XML entities.
		decoder.Strict = false
		for {
			tok, err := decoder.Token()
			if err == io.EOF {
				return
			}
			if err != nil {
				respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "offset: %d xml error: %v", decoder.InputOffset(), err))
				return
			}
			tok = xml.CopyToken(tok)
			if !SendXML(ctx, eventC, XMLEvent{tok, decoder.InputOffset()}) {
				return
			}
		}
	}()
	return eventC, errC
}

// SendXML sends an XMLEvent to the provided channel and returns true, otherwise if the context is done, it returns false.
func SendXML(ctx context.Context, xmlC chan<- XMLEvent, xml XMLEvent) bool {
	select {
	case <-ctx.Done():
		return false
	case xmlC <- xml:
		return true
	}
}

// Attrs returns all []xml.Attrs encounted on an XMLEvent.
func Attrs(xe XMLEvent) []xml.Attr {
	if se, ok := xe.Token.(xml.StartElement); ok {
		return se.Attr
	}
	return nil
}
