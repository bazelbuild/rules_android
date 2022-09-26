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
	"strings"

	rdpb "src/tools/ak/res/proto/res_data_go_proto"
	"src/tools/ak/res/res"
	"src/tools/ak/res/respipe/respipe"
	"src/tools/ak/res/resxml/resxml"
)

// nonValuesParse searches a non-values xml document for ID declarations. It creates ID
// resources for any declarations it finds.
func nonValuesParse(ctx context.Context, xmlC <-chan resxml.XMLEvent) (<-chan *rdpb.Resource, <-chan error) {
	resC := make(chan *rdpb.Resource)
	errC := make(chan error)
	go func() {
		defer close(resC)
		defer close(errC)
		for xe := range xmlC {
			for _, a := range resxml.Attrs(xe) {
				if strings.HasPrefix(a.Value, res.GeneratedIDPrefix) {
					unparsed := strings.Replace(a.Value, res.GeneratedIDPrefix, "@id", 1)
					fqn, err := res.ParseName(unparsed, res.ID)
					if err != nil {
						if !respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%s: unparsable id attribute: %+v: %v", a.Value, xe, err)) {
							return
						}
						continue
					}
					r := new(rdpb.Resource)
					if err := fqn.SetResource(r); err != nil {
						if !respipe.SendErr(ctx, errC, respipe.Errorf(ctx, "%s: name->proto failed: %+v", fqn, err)) {
							return
						}
						continue
					}
					if !respipe.SendRes(ctx, resC, r) {
						return
					}
				}
			}
		}
	}()
	return resC, errC
}
