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
	"encoding/xml"
)

var (
	// IDAttrName is the android:id attribute xml name.
	// It appears anywhere an xml document wishes to associate a tag to a given android id.
	IDAttrName = xml.Name{Space: "http://schemas.android.com/apk/res/android", Local: "id"}

	// ResourcesTagName <resources> tag wraps all xml documents in res/values directory. These
	// documents are reasonably well structured, and its children _normally_ end up becoming
	// ResourceValues in Android. The exception being <declare-styleable> and <attr> which
	// define how to interpret and store attributes in xml files outside of res/values.
	ResourcesTagName = xml.Name{Local: "resources"}

	// ItemTagName is used in various ways in a <resources> tag. If it is a direct child, it can
	// only denote an id resource. Otherwise, it can be a child of array/*-array and denotes the
	// type and wraps the value of the item of the array.
	ItemTagName = xml.Name{Local: "item"}

	// NameAttrName is an attribute that is expected to be encountered on every tag that is a
	// direct child of <resources>. The value of this tag is the name of the resource that is
	// being generated.
	NameAttrName = xml.Name{Local: "name"}

	// TypeAttrName is the type attribute xml name.
	// It appears in the <item> tag when the item wants to specify its type.
	TypeAttrName = xml.Name{Local: "type"}

	// EnumTagName <enum> appears beneath <attr/> tags to define valid enum values for an attribute.
	EnumTagName = xml.Name{Local: "enum"}

	// FlagTagName <flag> appears beneath <attr/> tags to define valid flag values for an attribute.
	FlagTagName = xml.Name{Local: "flag"}

	// ResourcesTagToType maps the child tag name of resources to the resource type it will generate.
	ResourcesTagToType = map[string]Type{
		"array":             Array,
		"integer-array":     Array,
		"string-array":      Array,
		"attr":              Attr,
		"^attr-private":     AttrPrivate,
		"bool":              Bool,
		"color":             Color,
		"configVarying":     ConfigVarying,
		"dimen":             Dimen,
		"drawable":          Drawable,
		"fraction":          Fraction,
		"id":                ID,
		"integer":           Integer,
		"layout":            Layout,
		"plurals":           Plurals,
		"string":            String,
		"style":             Style,
		"declare-styleable": Styleable,
	}

	// ResourcesChildToSkip a map containing child tags that can be skipped while parsing resources.
	ResourcesChildToSkip = map[xml.Name]bool{
		{Local: "skip"}:        true,
		{Local: "eat-comment"}: true,
		{Local: "public"}:      true,
	}
)

const (
	// GeneratedIDPrefix prefixes an attribute value whose name is IDAttrName, it indicates that
	// this id likely does not exist outside of the current document and a new Id Resource for
	// this value.
	GeneratedIDPrefix = "@+id"
)
