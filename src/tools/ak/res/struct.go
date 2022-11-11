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

// Package res handles understanding and representing information about Android resources.
package res

import (
	"errors"
	"fmt"
	"strconv"
	"strings"

	rdpb "src/tools/ak/res/proto/res_data_go_proto"
)

var (
	// ErrWrongType occurs when a type is used in an operation that it does not support.
	ErrWrongType = errors.New("this type cannot be used in this operation")
)

// Type of resource (eg: string, layout, drawable)
type Type rdpb.Resource_Type

// Enum converts a Type into a enum proto value
func (t Type) Enum() (rdpb.Resource_Type, error) {
	if !t.IsSerializable() {
		return rdpb.Resource_Type(ValueType), ErrWrongType
	}
	return rdpb.Resource_Type(t), nil
}

// IsSerializable indicates that the Type can be converted to a proto (some types are only for in memory operations).
func (t Type) IsSerializable() bool {
	for _, a := range nonProtoTypes {
		if t == a {
			return false
		}
	}
	return true
}

// NestedClassName is the R.java nested class name for this type (if the type is understood by android).
func (t Type) NestedClassName() (string, error) {
	if !t.IsReal() {
		return "", ErrWrongType
	}
	return typeToString[t], nil
}

// IsReal indicates that the type is known to the android framework.
func (t Type) IsReal() bool {
	for _, a := range nonProtoTypes {
		if a == t {
			return false
		}
	}
	return true
}

// From frameworks/base/tools/aapt2/Resource.h, except UnknownType and ValueType
// TODO(mauriciogg): use proto definitions and remove ValueType and UnknownType.
const (
	// UnknownType needs to be zero value
	UnknownType Type = -2
	ValueType        = -1

	// Anim represents Android Anim resource types.
	Anim = Type(rdpb.Resource_ANIM)
	// Animator represents Android Animator resource types.
	Animator = Type(rdpb.Resource_ANIMATOR)
	// Array represents Android Array resource types.
	Array = Type(rdpb.Resource_ARRAY)
	// Attr represents Android Attr resource types.
	Attr = Type(rdpb.Resource_ATTR)
	// AttrPrivate represents Android AttrPrivate resource types.
	AttrPrivate = Type(rdpb.Resource_ATTR_PRIVATE)
	// Bool represents Android Bool resource types.
	Bool = Type(rdpb.Resource_BOOL)
	// Color represents Android Color resource types.
	Color = Type(rdpb.Resource_COLOR)
	// ConfigVarying represents Android ConfigVarying resource types, not really a type, but it shows up in some CTS tests
	ConfigVarying = Type(rdpb.Resource_CONFIG_VARYING)
	// Dimen represents Android Dimen resource types.
	Dimen = Type(rdpb.Resource_DIMEN)
	// Drawable represents Android Drawable resource types.
	Drawable = Type(rdpb.Resource_DRAWABLE)
	// Font represents Android Font resource types.
	Font = Type(rdpb.Resource_FONT)
	// Fraction represents Android Fraction resource types.
	Fraction = Type(rdpb.Resource_FRACTION)
	// ID represents Android Id resource types.
	ID = Type(rdpb.Resource_ID)
	// Integer represents Android Integer resource types.
	Integer = Type(rdpb.Resource_INTEGER)
	// Interpolator represents Android Interpolator resource types.
	Interpolator = Type(rdpb.Resource_INTERPOLATOR)
	// Layout represents Android Layout resource types.
	Layout = Type(rdpb.Resource_LAYOUT)
	// Menu represents Android Menu resource types.
	Menu = Type(rdpb.Resource_MENU)
	// Mipmap represents Android Mipmap resource types.
	Mipmap = Type(rdpb.Resource_MIPMAP)
	// Navigation represents Android Navigation resource types.
	Navigation = Type(rdpb.Resource_NAVIGATION)
	// Plurals represents Android Plurals resource types.
	Plurals = Type(rdpb.Resource_PLURALS)
	// Raw represents Android Raw resource types.
	Raw = Type(rdpb.Resource_RAW)
	// String represents Android String resource types.
	String = Type(rdpb.Resource_STRING)
	// Style represents Android Style resource types.
	Style = Type(rdpb.Resource_STYLE)
	// Styleable represents Android Styleable resource types.
	Styleable = Type(rdpb.Resource_STYLEABLE)
	// Transition represents Android Transition resource types.
	Transition = Type(rdpb.Resource_TRANSITION)
	// XML represents Android Xml resource types.
	XML = Type(rdpb.Resource_XML)
)

var (
	// A fixed mapping between the string representation of a type and its Type.
	typeToString = map[Type]string{
		Anim:          "anim",
		Animator:      "animator",
		Array:         "array",
		Attr:          "attr",
		AttrPrivate:   "^attr-private",
		Bool:          "bool",
		Color:         "color",
		ConfigVarying: "configVarying",
		Dimen:         "dimen",
		Drawable:      "drawable",
		Fraction:      "fraction",
		Font:          "font",
		ID:            "id",
		Integer:       "integer",
		Interpolator:  "interpolator",
		Layout:        "layout",
		Menu:          "menu",
		Mipmap:        "mipmap",
		Navigation:    "navigation",
		Plurals:       "plurals",
		Raw:           "raw",
		String:        "string",
		Style:         "style",
		Styleable:     "styleable",
		Transition:    "transition",
		XML:           "xml",
	}
	stringToType = make(map[string]Type)
	// AllTypes is a list of all known resource types.
	AllTypes = make([]Type, 0, len(typeToString))

	// These types are not allowed to be serialized into proto format.
	nonProtoTypes = []Type{ValueType, UnknownType}
)

// Kind indicates what type of resource file emits this resource. A resource can be found in
// res/values folder (and therefore is a Value - which can be represented as a ResourceValue in
// Android) or in folders outside of res/values (such as res/layout) and thus are not ResourceValues
// but rather some external resource (such as an image or parsed xml file).
type Kind uint8

const (
	// Unknown should not be encountered.
	Unknown Kind = iota
	// Value can only be encountered in res/values folders.
	Value
	// NonValue can not be encountered in res/values folders.
	NonValue
	// Both  is a Kind of Type which may be inside a res/values folder or in another res/ folder.
	Both
)

var (
	kindToString = map[Kind]string{
		Unknown:  "Unknown",
		Value:    "Value",
		NonValue: "NonValue",
		Both:     "Both",
	}

	// A fixed mapping between Type and Kind.
	TypesToKind = map[Type]Kind{
		Anim:          NonValue,
		Animator:      NonValue,
		Array:         Value,
		Attr:          Value,
		AttrPrivate:   Value,
		Bool:          Value,
		Color:         Both,
		ConfigVarying: Value,
		Dimen:         Value,
		Drawable:      NonValue,
		Font:          NonValue,
		Fraction:      Value,
		ID:            Value,
		Integer:       Value,
		Interpolator:  NonValue,
		Layout:        NonValue,
		Menu:          NonValue,
		Mipmap:        NonValue,
		Navigation:    NonValue,
		Plurals:       Value,
		Raw:           NonValue,
		String:        Value,
		Style:         Value,
		Styleable:     Value,
		Transition:    NonValue,
		XML:           NonValue,
	}
)

// Density represents the dpi value of a resource.
type Density uint16

// From frameworks/base/core/java/Android/content/res/Configuration.java
const (
	// UnspecifiedDensity is a default value indicating no dpi has been specified
	UnspecifiedDensity Density = 0

	// LDPI has a dpi of 120
	LDPI Density = 120
	// MDPI has a dpi of 160
	MDPI Density = 160
	// TVDPI has a dpi of 213
	TVDPI Density = 213
	// HDPI has a dpi of 240
	HDPI Density = 240
	// XhDPI has a dpi of 320
	XhDPI Density = 320
	// XxhDPI has a dpi of 480
	XxhDPI Density = 480
	// XxxhDPI has a dpi of 640
	XxxhDPI Density = 640
	// AnyDPI indicates a resource which can be any dpi.
	AnyDPI Density = 0xfffe
	// NoDPI indicates the resources have no dpi constraints
	NoDPI     Density = 0xffff
	dpiSuffix         = "dpi"
)

var (
	densityToStr = map[Density]string{
		LDPI:    "ldpi",
		MDPI:    "mdpi",
		TVDPI:   "tvdpi",
		HDPI:    "hdpi",
		XhDPI:   "xhdpi",
		XxhDPI:  "xxhdpi",
		XxxhDPI: "xxxhdpi",
		AnyDPI:  "anydpi",
		NoDPI:   "nodpi",
	}
	strToDensity = make(map[string]Density)
)

// ParseValueOrType converts a string into a value type or well known type
func ParseValueOrType(s string) (Type, error) {
	if s == "values" {
		return ValueType, nil
	}
	return ParseType(s)
}

// ParseType converts a string into a well known type
func ParseType(s string) (Type, error) {
	if t, ok := stringToType[s]; ok {
		return t, nil
	}
	return UnknownType, fmt.Errorf("%s: unknown type", s)
}

// String for Type structs corresponds to the string format known to Android.
func (t Type) String() string {
	if s, ok := typeToString[t]; ok {
		return s
	}
	return fmt.Sprintf("Type(%d)", t)
}

// Kind indicates the resource kind of this type.
func (t Type) Kind() Kind {
	if t == ValueType {
		return Value
	}
	if t, ok := TypesToKind[t]; ok {
		return t
	}
	return Unknown
}

// ParseDensity converts a string representation of a density into a Density.
func ParseDensity(s string) (Density, error) {
	if d, ok := strToDensity[s]; ok {
		return d, nil
	}
	if strings.HasSuffix(s, dpiSuffix) {
		parsed, err := strconv.ParseUint(s[0:len(s)-len(dpiSuffix)], 10, 16)
		if err != nil {
			return 0, fmt.Errorf("%s: unparsable: %v", s, err)
		}
		return Density(parsed), nil
	}
	return UnspecifiedDensity, nil
}

func init() {
	for k, v := range typeToString {
		AllTypes = append(AllTypes, k)
		stringToType[v] = k
	}
	for k, v := range densityToStr {
		strToDensity[v] = k
	}
}
