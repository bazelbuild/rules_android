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

package patch

import (
	"bufio"
	"bytes"
	"encoding/xml"
	"strings"
	"testing"

	"src/common/golang/xml2"
	"src/tools/ak/manifestutils"
)

const (
	manifestWithAppClass = `<?xml version="1.0" ?>
<manifest package="com.google.android.other" xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-sdk android:minSdkVersion="10" android:targetSdkVersion="21"/>
  <application android:allowBackup="true" android:icon="@drawable/ic_launcher" android:name="android.app.OtherApplication" android:label="@string/app_name" android:theme="@style/AppTheme">
    <activity android:label="@string/app_name" android:name="com.google.android.test.Activity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>`

	manifestWithAppClassAtEnd = `<?xml version="1.0" ?>
<manifest package="com.google.android.end" xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-sdk android:minSdkVersion="10" android:targetSdkVersion="21"/>
  <application android:allowBackup="true" android:icon="@drawable/ic_launcher" android:label="@string/app_name" android:theme="@style/AppTheme" android:name="android.app.EndApplication">
    <activity android:label="@string/app_name" android:name="com.google.android.test.Activity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>`

	manifestWithNoAppClass = `<?xml version="1.0" ?>
<manifest package="com.google.android.test" xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-sdk android:minSdkVersion="10" android:targetSdkVersion="21"/>
  <application android:allowBackup="true" android:icon="@drawable/ic_launcher" android:label="@string/app_name" android:theme="@style/AppTheme">
    <activity android:label="@string/app_name" android:name="com.google.android.test.Activity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>`
)

func TestParsing(t *testing.T) {
	tests := []struct {
		name        string
		manifestXML string
		wantPkg     string
		wantApp     string
	}{
		{
			name:        "withAppClass",
			manifestXML: manifestWithAppClass,
			wantPkg:     "com.google.android.other",
			wantApp:     "android.app.OtherApplication",
		},
		{
			name:        "withAppClassAtEnd",
			manifestXML: manifestWithAppClassAtEnd,
			wantPkg:     "com.google.android.end",
			wantApp:     "android.app.EndApplication",
		},
		{
			name:        "noAppClass",
			manifestXML: manifestWithNoAppClass,
			wantPkg:     "com.google.android.test",
			wantApp:     "",
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			var manifest manifestutils.Manifest
			xml.Unmarshal([]byte(test.manifestXML), &manifest)
			if manifest.Package != test.wantPkg {
				t.Errorf("Parsed package name not correct: got: %q wanted: %q", manifest.Package, test.wantPkg)
			}
			if manifest.Application.Name != test.wantApp {
				t.Errorf("Parsed application class name not correct: got: %q wanted: %q", manifest.Application.Name, test.wantApp)
			}
		})
	}
}

func TestSetAppName(t *testing.T) {
	tests := []struct {
		name            string
		manifestXML     string
		newApp          string
		wantManifestXML string
	}{
		{
			name:        "withAppClass",
			manifestXML: manifestWithAppClass,
			newApp:      "android.app.OtherTestApplication",
		},
		{
			name:        "withAppClassAtEnd",
			manifestXML: manifestWithAppClassAtEnd,
			newApp:      "android.app.EndTestApplication",
		},
		{
			name:        "noAppClass",
			manifestXML: manifestWithNoAppClass,
			newApp:      "android.app.TestApplication",
		},
	}
	elems := map[string]map[string]xml.Attr{"application": make(map[string]xml.Attr)}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			elems["application"]["name"] = xml.Attr{
				Name: xml.Name{Space: manifestutils.NameSpace, Local: "name"}, Value: test.newApp}
			var b bytes.Buffer
			e := xml2.NewEncoder(bufio.NewWriter(&b))
			manifestutils.Patch(xml.NewDecoder(strings.NewReader(test.manifestXML)), e, elems)
			if err := e.Flush(); err != nil {
				t.Fatalf("Error occurred during encoder flush: %v", err)
			}
			var manifest manifestutils.Manifest
			xml.Unmarshal([]byte(b.String()), &manifest)
			if manifest.Application.Name != test.newApp {
				t.Errorf("New application class name not correct: got: %q wanted: %q", manifest.Application.Name, test.newApp)
			}
		})
	}
}

func TestSetAppName_xmlEncoding(t *testing.T) {
	wantManifestXML := `<?xml version="1.0" ?>
<manifest package="com.google.android.other" xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-sdk android:minSdkVersion="10" android:targetSdkVersion="21"></uses-sdk>
  <application android:allowBackup="true" android:icon="@drawable/ic_launcher" android:name="android.app.OtherApplication" android:label="@string/app_name" android:theme="@style/AppTheme">
    <activity android:label="@string/app_name" android:name="com.google.android.test.Activity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"></action>
        <category android:name="android.intent.category.LAUNCHER"></category>
      </intent-filter>
    </activity>
  </application>
</manifest>`

	elems := map[string]map[string]xml.Attr{
		"application": map[string]xml.Attr{"name": xml.Attr{
			Name: xml.Name{Space: manifestutils.NameSpace, Local: "name"}, Value: "android.app.OtherApplication"}}}
	var b bytes.Buffer
	e := xml2.NewEncoder(bufio.NewWriter(&b))
	manifestutils.Patch(xml.NewDecoder(strings.NewReader(manifestWithAppClass)), e, elems)
	if err := e.Flush(); err != nil {
		t.Fatalf("Error occurred during encoder flush: %v", err)
	}
	if b.String() != wantManifestXML {
		t.Errorf("got: <%s> expected: <%s>", b.String(), wantManifestXML)
	}
}
