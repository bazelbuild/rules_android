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

// Package manifestutils provides common methods to interact with and modify AndroidManifest.xml files.
package manifestutils

import (
	"encoding/xml"
	"io"
	"log"
	"strings"

	"src/common/golang/xml2"
)

// Constant attribute names used in an AndroidManifest.
const (
	NameSpace           = "http://schemas.android.com/apk/res/android"
	ElemManifest        = "manifest"
	AttrPackage         = "package"
	AttrSplit           = "split"
	AttrFeatureName     = "featureName"
	AttrSharedUserID    = "sharedUserId"
	AttrSharedUserLabel = "sharedUserLabel"
	AttrVersionCode     = "versionCode"
	AttrVersionName     = "versionName"
)

var (
	// NoNSAttrs contains attributes that are not namespaced.
	NoNSAttrs = map[string]bool{
		AttrPackage:     true,
		AttrSplit:       true,
		AttrFeatureName: true}
)

// Manifest is the XML root that we want to parse.
type Manifest struct {
	XMLName         xml.Name    `xml:"manifest"`
	Package         string      `xml:"package,attr"`
	SharedUserID    string      `xml:"sharedUserId,attr"`
	SharedUserLabel string      `xml:"sharedUserLabel,attr"`
	VersionCode     string      `xml:"versionCode,attr"`
	VersionName     string      `xml:"versionName,attr"`
	Application     Application `xml:"application"`
}

// Application is the XML tag that we want to parse.
type Application struct {
	XMLName xml.Name `xml:"application"`
	Name    string   `xml:"http://schemas.android.com/apk/res/android name,attr"`
}

// Encoder takes the xml.Token and encodes it, interface allows us to use xml2.Encoder.
type Encoder interface {
	EncodeToken(xml.Token) error
}

// Patch updates an AndroidManifest by patching the attributes of existing elements.
//
// Attributes that are already defined on the element are updated, while missing
// attributes are added to the element's attributes. Elements in patchElems that are
// missing from the manifest are ignored.
func Patch(dec *xml.Decoder, enc Encoder, patchElems map[string]map[string]xml.Attr) error {
	for {
		t, err := dec.Token()
		if err != nil {
			if err == io.EOF {
				break
			}
			return err
		}
		switch tt := t.(type) {
		case xml.StartElement:
			elem := tt.Name.Local
			if attrs, ok := patchElems[elem]; ok {
				found := make(map[string]bool)
				for i, a := range tt.Attr {
					if attr, ok := attrs[a.Name.Local]; a.Name.Space == attr.Name.Space && ok {
						found[a.Name.Local] = true
						tt.Attr[i] = attr
					}
				}
				for _, attr := range attrs {
					if found[attr.Name.Local] {
						continue
					}

					tt.Attr = append(tt.Attr, attr)
				}
			}
			enc.EncodeToken(tt)
		default:
			enc.EncodeToken(tt)
		}
	}
	return nil
}

// WriteManifest writes an AndroidManifest with updates to patched elements.
func WriteManifest(dst io.Writer, src io.Reader, patchElems map[string]map[string]xml.Attr) error {
	e := xml2.NewEncoder(dst)
	if err := Patch(xml.NewDecoder(src), e, patchElems); err != nil {
		return err
	}
	return e.Flush()
}

// CreatePatchElements creates an element map from a string array of "element:attr:attr_value" entries.
func CreatePatchElements(attr []string) map[string]map[string]xml.Attr {
	patchElems := make(map[string]map[string]xml.Attr)
	for _, a := range attr {
		pts := strings.Split(a, ":")
		if len(pts) < 3 {
			log.Fatalf("Failed to parse attr to replace %s", a)
		}

		elem := pts[0]
		attr := pts[1]
		ns := NameSpace

		// https://developer.android.com/guide/topics/manifest/manifest-element
		if elem == ElemManifest && NoNSAttrs[attr] {
			ns = ""
		}

		if ais, ok := patchElems[elem]; ok {
			ais[attr] = xml.Attr{
				Name: xml.Name{Space: ns, Local: attr}, Value: pts[2]}
		} else {
			patchElems[elem] = map[string]xml.Attr{
				attr: xml.Attr{
					Name: xml.Name{Space: ns, Local: attr}, Value: pts[2]}}
		}
	}
	return patchElems
}
