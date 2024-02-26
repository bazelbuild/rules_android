// Copyright 2024 The Bazel Authors. All rights reserved.
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

// Package minsdkfloor is a AndroidManifest tool to enforce a floor on the
// minSdkVersion attribute.
package minsdkfloor

import (
	"bytes"
	"encoding/xml"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"path"
	"strconv"
	"sync"

	"src/common/golang/xml2"
	"src/tools/ak/types"
)

var (
	// Cmd defines the command to run minsdk
	Cmd = types.Command{
		Init: Init,
		Run:  Run,
		Desc: desc,
		Flags: []string{
			"out",
		},
	}

	initOnce sync.Once

	actionFlag      string
	manifestFlag    string
	minSdkFloorFlag int
	// Needed for SET_DEFAULT
	defaultMinSdkFlag string
	// Needed for BUMP and SET_DEFAULT
	outputFlag string
	logFlag    string
)

const (
	// action flag option: bump - update minSdkVersion if it's missing or has smaller value
	bump = "bump"
	// action flag option: set_default - update minSdkVersion if it's missing
	setDefault = "set_default"
)

// Init initializes mindex.
func Init() {
	initOnce.Do(func() {
		flag.StringVar(&actionFlag, "action", "", "Action to perform: either bump or set_default")
		flag.StringVar(&manifestFlag, "manifest", "", "AndroidManifest.xml of the instrumentation APK")
		flag.IntVar(&minSdkFloorFlag, "min_sdk_floor", 0, "Min SDK floor")
		flag.StringVar(&defaultMinSdkFlag, "default_min_sdk", "", "Default min SDK")
		flag.StringVar(&outputFlag, "output", "", "Output AndroidManifest.xml to generate.")
		flag.StringVar(&logFlag, "log", "", "Path to write the log to")
	})
}

func desc() string {
	return "Enforce minSdkVersion floor in generated manifest output"
}

// Run is the entry point for mindex.
func Run() {

	if actionFlag != bump && actionFlag != setDefault {
		log.Fatalf("Action must be either %s or %s", bump, setDefault)
	}

	if manifestFlag == "" {
		log.Fatal("Missing manifest path")
	}

	// Load the XML from inputManifest
	manifest, err := os.ReadFile(manifestFlag)
	if err != nil {
		log.Fatalf("Error reading manifest: %v\n", err)
	}

	updatedManifest := manifest
	logMessage := ""
	if actionFlag == bump {
		updatedManifest, logMessage, err = BumpMinSdk(manifest, minSdkFloorFlag)
	} else {
		updatedManifest, logMessage, err = SetDefaultMinSdk(manifest, defaultMinSdkFlag)
	}
	if err != nil {
		log.Fatal(fmt.Printf("Error modifying minSdkVersion: %v\n", err))
	}

	err = os.MkdirAll(path.Dir(outputFlag), 0755)
	if err != nil && !os.IsExist(err) {
		log.Fatal(err)
	}
	err = os.WriteFile(outputFlag, updatedManifest, 0644)
	if err != nil {
		log.Fatal(fmt.Printf("Error writing output manifest: %v\n", err))
	}

	if logFlag != "" {
		err := os.MkdirAll(path.Dir(logFlag), 0755)
		if err != nil && !os.IsExist(err) {
			log.Fatalf("Error creating folder for log file: %v\n", err)
		}
		file, err := os.Create(logFlag)
		if err != nil {
			log.Fatalf("Error creating log file: %v\n", err)
		}
		defer file.Close()
		_, err = file.WriteString(logMessage)
		if err != nil {
			log.Fatalf("Error writing to log: %v\n", err)
			return
		}
	}
}

// addMinSdkVersionAttr adds the minSdkVersion attribute
func addMinSdkVersionAttr(elem xml.StartElement, minSdk string, sdkType string) (xml.Token, string) {
	elem.Attr = append(elem.Attr, xml.Attr{Name: xml.Name{Space: "android", Local: "minSdkVersion"}, Value: minSdk})
	message := fmt.Sprintf("No minSdkVersion attribute found while %s is specified (%s). Min SDK added.", sdkType, minSdk)
	return elem, message
}

// addUsesSdkElement creates an uses-sdk element
func addUsesSdkElement(minSdk string, sdkType string) (string, xml.StartElement, xml.EndElement) {
	usesSdkStart := xml.StartElement{
		Name: xml.Name{Space: "", Local: "uses-sdk"},
		Attr: []xml.Attr{{Name: xml.Name{Space: "android", Local: "minSdkVersion"}, Value: minSdk}},
	}
	usesSdkEnd := xml.EndElement{Name: xml.Name{Space: "", Local: "uses-sdk"}}
	message := fmt.Sprintf("No uses-sdk element found while %s is specified (%s). Min SDK added.", sdkType, minSdk)
	return message, usesSdkStart, usesSdkEnd
}

// updateMinSdkVersion updates the minSdkVersion attribute if its value is numeric and less than input
func updateMinSdkVersion(attr xml.Attr, minSdk string, sdkType string) (xml.Attr, string, bool, error) {
	minSdkInt, err := strconv.Atoi(minSdk)
	if err != nil {
		message := fmt.Sprintf("Input minSdk (%s) should be numeric", minSdk)
		return attr, message, false, err
	}
	sdkInt, err := strconv.Atoi(attr.Value)
	message := ""
	if err != nil {
		message = fmt.Sprintf("Placeholder used for the minSdkVersion attribute (%s). Manifest unchanged.", attr.Value)
		return attr, message, false, nil
	}
	if sdkInt < minSdkInt {
		attr.Value = minSdk
		message = fmt.Sprintf("minSdkVersion attribute specified in the manifest (%d) is less than the %s (%s). Min SDK replaced.", sdkInt, sdkType, minSdk)
		return attr, message, true, nil
	}
	message = fmt.Sprintf("minSdkVersion attribute specified in the manifest (%d) is no less than the %s (%s). Min SDK unchanged.", sdkInt, sdkType, minSdk)
	return attr, message, false, nil
}

// BumpMinSdk ensures that the minSdkVersion attribute is >= than the specified floor,
// and if the attribute is either not specified or less than the floor,
// sets it to the floor.
func BumpMinSdk(manifest []byte, newMinSdk int) ([]byte, string, error) {
	if newMinSdk == 0 {
		return manifest, "No min SDK floor specified. Manifest unchanged.", nil
	}
	minSdkStr := fmt.Sprintf("%d", newMinSdk)
	return enforceMinSDKVersion(manifest, minSdkStr, "floor", true)
}

// SetDefaultMinSdk set minSdkVersion if it's undefined
func SetDefaultMinSdk(manifest []byte, defaultMinSdk string) ([]byte, string, error) {
	if defaultMinSdk == "" {
		return manifest, "No default min SDK floor specified. Manifest unchanged.", nil
	}

	return enforceMinSDKVersion(manifest, defaultMinSdk, "default", false)
}

func enforceMinSDKVersion(
	manifest []byte,
	minSdk string,
	sdkType string,
	shouldUpdateMinSdkVersion bool) ([]byte, string, error) {

	decoder := xml.NewDecoder(bytes.NewReader(manifest))
	var elements []xml.Token
	var message string
	var xmlUpdated bool = false
	usesSdkAdded := false

	for {
		token, err := decoder.Token()
		if err == io.EOF {
			break
		} else if err != nil {
			return nil, "", err
		}

		switch token.(type) {
		case xml.ProcInst:
			// For some reason the []byte part need to be cloned, otherwise encoder produces nonsense
			elements = append(elements, token.(xml.ProcInst).Copy())
			continue

		case xml.Comment:
			// For some reason the []byte part need to be cloned, otherwise encoder produces nonsense
			elements = append(elements, token.(xml.Comment).Copy())
			continue

		case xml.CharData:
			// For some reason the []byte part need to be cloned, otherwise encoder produces nonsense
			elements = append(elements, token.(xml.CharData).Copy())
			continue

		case xml.StartElement:
			if token.(xml.StartElement).Name.Local == "uses-sdk" {
				minSdkVersionExists := false
				elem := token.(xml.StartElement)
				for i, attr := range elem.Attr {
					if attr.Name.Local == "minSdkVersion" {
						minSdkVersionExists = true
						if shouldUpdateMinSdkVersion {
							updated := false
							attr, message, updated, err = updateMinSdkVersion(attr, minSdk, sdkType)
							if err != nil {
								return nil, "", err
							}
							xmlUpdated = xmlUpdated || updated
							elem.Attr[i] = attr
						}
					}
				}
				if !minSdkVersionExists {
					token, message = addMinSdkVersionAttr(elem, minSdk, sdkType)
					xmlUpdated = true
				}
				usesSdkAdded = true
			}

		case xml.EndElement:
			// Create 'uses-sdk' if not already presents
			if token.(xml.EndElement).Name.Local == "manifest" && !usesSdkAdded {
				msg, usesSdkStart, usesSdkEnd := addUsesSdkElement(minSdk, sdkType)
				message = msg
				elements = append(elements, usesSdkStart, usesSdkEnd, xml.CharData{'\n'})
				xmlUpdated = true
				usesSdkAdded = true
			}
		}
		elements = append(elements, token)
	}
	// If no changes to XML content, skips encode and returns input
	if !xmlUpdated {
		return manifest, message, nil
	}

	// Re-encode the modified XML
	buffer := bytes.Buffer{}
	encoder := xml2.NewEncoder(&buffer)

	for _, token := range elements {
		err := encoder.EncodeToken(token)
		if err != nil {
			return nil, "", err
		}
	}

	encoder.Flush()
	// Make uses-sdk a self-closing element
	return bytes.ReplaceAll(buffer.Bytes(), []byte("></uses-sdk>"), []byte("/>")), message, nil
}
