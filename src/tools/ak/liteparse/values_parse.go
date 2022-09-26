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
	"context"
	"encoding/xml"
	"fmt"

	rdpb "src/tools/ak/res/proto/res_data_go_proto"
	rmpb "src/tools/ak/res/proto/res_meta_go_proto"
	"src/tools/ak/res/res"
	"src/tools/ak/res/respipe/respipe"
	"src/tools/ak/res/resxml/resxml"
)

// valuesParse handles all tags beneath <resources> and extracts the associated
// ResourceType/names. Any encountered resources or errors are passed back on the returned channels.
func valuesParse(ctx context.Context, xmlC <-chan resxml.XMLEvent) (<-chan *rdpb.Resource, <-chan error) {
	resC := make(chan *rdpb.Resource)
	errC := make(chan error)
	go func() {
		defer close(resC)
		defer close(errC)
		for {
			xe, ok := resxml.ConsumeUntil(res.ResourcesTagName, xmlC)
			if !ok {
				return
			}
			resChildrenC := resxml.ForwardChildren(ctx, xe, xmlC)
			for xe := range resChildrenC {
				se, ok := xe.Token.(xml.StartElement)
				if !ok {
					// we ignore all non-start elements during a mini-parse.
					continue
				}

				tagChildrenC := resxml.ForwardChildren(ctx, xe, resChildrenC)
				ctx := respipe.PrefixErr(ctx, fmt.Sprintf("tag-name: %s at: %d: ", se.Name, xe.Offset))
				if t, ok := res.ResourcesTagToType[se.Name.Local]; ok {
					if !minResChildParse(ctx, xe, t, tagChildrenC, resC, errC) {
						return
					}
				} else if resxml.SloppyMatches(se.Name, res.ItemTagName) {
					if !itemParse(ctx, xe, tagChildrenC, resC, errC) {
						return
					}
				}
				for range tagChildrenC {
					// exhaust any children beneath this tag, we did not need them in the mini-parse.
				}
			}
		}
	}()
	return resC, errC
}

// itemParse handles <item name="xxxx" type="yyy"></item> tags that are children of <resources/>
func itemParse(ctx context.Context, xe resxml.XMLEvent, childC <-chan resxml.XMLEvent, resC chan<- *rdpb.Resource, errC chan<- error) bool {
	name, err := extractName(xe)
	if err != nil {
		return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%v: expected to encounter name attribute: %v", xe, err))
	}
	var tv string
	for _, a := range resxml.Attrs(xe) {
		if resxml.SloppyMatches(res.TypeAttrName, a.Name) {
			tv = a.Value
		}
	}
	if tv == "" {
		return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%v: needs type atttribute", xe))
	}
	t, err := res.ParseType(tv)
	if err != nil {
		return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%q: cannot convert to type: %v", tv, err))
	}
	fqn, err := res.ParseName(name, t)
	if err != nil {
		return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%q / type: %s: convert to fqn: %v", name, t, err))
	}
	r := new(rdpb.Resource)
	if err := fqn.SetResource(r); err != nil {
		return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%v: name->proto failed: %v", fqn, err))
	}
	return respipe.SendRes(ctx, resC, r)
}

// Returns the value of the name attribute or an error.
func extractName(xe resxml.XMLEvent) (string, error) {
	for _, a := range resxml.Attrs(xe) {
		if resxml.SloppyMatches(res.NameAttrName, a.Name) {
			return a.Value, nil
		}
	}
	return "", fmt.Errorf("Expected to encounter name attribute within: %v", resxml.Attrs(xe))
}

// minResChildParse handles a single top-level tag beneath <resources> and extracts all ResourceTypes/Names beneath it. It returns false if it detects that the context is done.
func minResChildParse(ctx context.Context, xe resxml.XMLEvent, t res.Type, childC <-chan resxml.XMLEvent, resC chan<- *rdpb.Resource, errC chan<- error) bool {
	name, err := extractName(xe)
	if err != nil {
		return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%#v: needs name attribute: %v", xe, err))
	}

	fqn, err := res.ParseName(name, t)
	if err != nil {
		return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%s: invalid name: %v", name, err))
	}

	r := new(rdpb.Resource)
	if err := fqn.SetResource(r); err != nil {
		return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%v: name->proto failed: %v", fqn, err))
	}
	if fqn.Type == res.Styleable {
		md, ok := parseStyleableChildren(ctx, childC, resC, errC)
		if !ok {
			return false
		}
		if err := fqn.SetMetaData(md); err != nil {
			return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%v: could not set stylablemeta: %v", fqn, err))
		}
		r.StyleableValue = md
	}
	if fqn.Type == res.Attr && !parseAttrChildren(ctx, childC, resC, errC) {
		return false
	}

	return respipe.SendRes(ctx, resC, r)
}

// parseAttrChildren looks at the children of an <attr> tag and determines if any of them creates resources.
// If it realizes that the provided ctx is canceled, it returns true, otherwise false.
func parseAttrChildren(ctx context.Context, xmlC <-chan resxml.XMLEvent, resC chan<- *rdpb.Resource, errC chan<- error) bool {
	for c := range xmlC {
		ce, ok := c.Token.(xml.StartElement)
		if !ok {
			// do not care about non-start element events.
			continue
		}
		if !resxml.SloppyMatches(res.EnumTagName, ce.Name) && !resxml.SloppyMatches(res.FlagTagName, ce.Name) {
			// only want <enum> or <flag> elements
			continue
		}

		enumFlagName, err := extractName(c)
		if err != nil {
			return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%v: flag / enum should have had a name attribute: %v", ce, err))
		}
		cFqn, err := res.ParseName(enumFlagName, res.ID)
		if err != nil {
			return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%v: could not parse child of <attr>: %v", ce, err))
		}
		cr := new(rdpb.Resource)
		if err := cFqn.SetResource(cr); err != nil {
			return respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%v: name->proto failed: %v", ce, err))
		}
		if !respipe.SendRes(ctx, resC, cr) {
			return false
		}
	}
	return true
}

// parseStyleableChildren looks at the children of a <declare-stylable> tag and determines what resources they create.
func parseStyleableChildren(ctx context.Context, xmlC <-chan resxml.XMLEvent, resC chan<- *rdpb.Resource, errC chan<- error) (*rmpb.StyleableMetaData, bool) {
	var attrNames []string
	for c := range xmlC {
		if _, ok := c.Token.(xml.StartElement); !ok {
			// skip events besides start element.
			continue
		}
		name, err := extractName(c)
		if err != nil {
			// being liberal with what we can encounter under a <declare-styleable> tag.
			continue
		}
		attrFqn, err := res.ParseName(name, res.Attr)
		if err != nil {
			return nil, respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%q: could not parse name to fqn: %v", name, err))
		}
		if attrFqn.Type != res.Attr {
			return nil, respipe.SendErr(
				ctx, errC, respipe.Errorf(ctx, "%v: name->nameid proto failed: %v", attrFqn, res.ErrWrongType))
		}

		attrNames = append(attrNames, attrFqn.String())
		if attrFqn.Package == "android" {
			// since we're not generating android attributes (they already exist already)
			// omit the resource proto for these attrs.
			continue
		}

		if attrFqn.Type == res.Attr {
			ctx := respipe.PrefixErr(ctx, fmt.Sprintf("%q: <attr> child: ", name))
			childC := resxml.ForwardChildren(ctx, c, xmlC)
			if !parseAttrChildren(ctx, childC, resC, errC) {
				return nil, false
			}
		}

		attrR := new(rdpb.Resource)
		if err := attrFqn.SetResource(attrR); err != nil {
			return nil, respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%v: name->proto failed: %v", attrFqn, err))
		}

		if !respipe.SendRes(ctx, resC, attrR) {
			return nil, false
		}

	}
	return &rmpb.StyleableMetaData{
		FqnAttributes: attrNames,
	}, true
}
