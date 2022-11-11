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

package res

import (
	"fmt"
	"strings"

	rdpb "src/tools/ak/res/proto/res_data_go_proto"
	rmpb "src/tools/ak/res/proto/res_meta_go_proto"
	"google.golang.org/protobuf/proto"
)

// FullyQualifiedName represents the components of a name.
type FullyQualifiedName struct {
	Package string
	Type    Type
	Name    string
}

// ValuesResource represents a resource element.
type ValuesResource struct {
	Src     *PathInfo
	N       FullyQualifiedName
	Payload []byte
}

// SetResource sets all the name related fields on the top level resource proto.
func (f FullyQualifiedName) SetResource(r *rdpb.Resource) error {
	rt, err := f.Type.Enum()
	if err != nil {
		return err
	}
	r.ResourceType = rt
	r.Name = protoNameSanitizer.Replace(f.Name)
	return nil
}

// SetMetaData sets all name related fields for this style on a StyleableMetaData proto
func (f FullyQualifiedName) SetMetaData(md *rmpb.StyleableMetaData) error {
	if f.Type != Styleable {
		return ErrWrongType
	}
	md.Name = proto.String(protoNameSanitizer.Replace(f.Name))
	return nil
}

var (
	protoNameSanitizer = strings.NewReplacer(".", "_")
	javaNameSanitizer  = strings.NewReplacer(":", "_", ".", "_")
)

// JavaName returns a version of the FullyQualifiedName that should be used for resource identifier fields.
func (f FullyQualifiedName) JavaName() (string, error) {
	if !f.Type.IsReal() {
		return "", ErrWrongType
	}
	return javaNameSanitizer.Replace(f.Name), nil
}

// StyleableAttrName creates the java identifier for referencing this attribute in the given
// style.
func StyleableAttrName(styleable, attr FullyQualifiedName) (string, error) {
	if styleable.Type != Styleable || attr.Type != Attr {
		return "", ErrWrongType
	}
	js, err := styleable.JavaName()
	if err != nil {
		return "", err
	}
	ja, err := attr.JavaName()
	if err != nil {
		return "", err
	}

	if attr.Package == "android" {
		return fmt.Sprintf("%s_android_%s", js, ja), nil
	}
	return fmt.Sprintf("%s_%s", js, ja), nil
}

// ParseName is given a name string and optional context about the name (what type the name may be)
// and attempts to extract the local name, Type, and package from the unparsed input. The format of
// unparsed names is flexible and not well specified.
// A FullyQualifiedName's String method will emit pkg:type/name which every tool understands, but
// ParseName will encounter input like ?type:pkg/name - an undocumented, but legal way to specify a
// reference to a style. If unparsed is so mangled that a legal name cannot possibly be determined,
// it will return an error.
func ParseName(unparsed string, resType Type) (FullyQualifiedName, error) {
	fqn := removeRef(unparsed)
	fqn.Type = resType
	pkgIdx := strings.Index(fqn.Name, ":")
	typeIdx := strings.Index(fqn.Name, "/")
	if pkgIdx == 0 || typeIdx == 0 {
		return FullyQualifiedName{}, fmt.Errorf("malformed name %q - can not start with ':' or '/'", unparsed)
	}

	if typeIdx != -1 {
		if pkgIdx != -1 {
			if pkgIdx < typeIdx {
				// Package, type and name (pkg:type/name)
				t, err := ParseType(fqn.Name[pkgIdx+1 : typeIdx])
				if err != nil {
					// the name has illegal type in it that we'll never be able to scrub out.
					return FullyQualifiedName{}, err
				}
				fqn.Type = t
				fqn.Package = fqn.Name[:pkgIdx]
				fqn.Name = fqn.Name[typeIdx+1:]

			} else {
				// Package, type and name, type and package swapped (type:pkg/name)
				t, err := ParseType(fqn.Name[:typeIdx])
				if err != nil {
					// the name has illegal type in it that we'll never be able to scrub out.
					return FullyQualifiedName{}, err
				}
				fqn.Type = t
				fqn.Package = fqn.Name[typeIdx+1 : pkgIdx]
				fqn.Name = fqn.Name[pkgIdx+1:]
			}
		} else {
			// Only type and name (type/name)
			t, err := ParseType(fqn.Name[:typeIdx])
			if err != nil {
				// the name has illegal type in it that we'll never be able to scrub out.
				return FullyQualifiedName{}, err
			}
			fqn.Type = t
			fqn.Name = fqn.Name[typeIdx+1:]
		}
	} else {
		// Only package and name (pkg:name)
		if pkgIdx != -1 {
			fqn.Package = fqn.Name[:pkgIdx]
			fqn.Name = fqn.Name[pkgIdx+1:]
		}
	}

	if fqn.Package == "" {
		fqn.Package = "res-auto"
	}

	if fqn.Type == UnknownType {
		return FullyQualifiedName{}, fmt.Errorf("cannot determine type from %q and %v - not a valid name", unparsed, resType)
	}
	if fqn.Name == "" {
		return FullyQualifiedName{}, fmt.Errorf("cannot determine name from %q and %v - not a valid name", unparsed, resType)
	}
	return fqn, nil
}

func removeRef(unparsed string) (fqn FullyQualifiedName) {
	fqn.Name = unparsed
	if len(fqn.Name) > 2 && (strings.HasPrefix(fqn.Name, "@") || strings.HasPrefix(fqn.Name, "?")) {
		fqn.Name = fqn.Name[1:]
	}
	return
}

func (f FullyQualifiedName) String() string {
	return fmt.Sprintf("%s:%s/%s", f.Package, f.Type, f.Name)
}
