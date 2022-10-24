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

// Package generatemanifest is a command line tool to generate an empty AndroidManifest
package generatemanifest

import (
	"io"
	"strings"
	"testing"

	"github.com/google/go-cmp/cmp"
)

type fakeFile struct {
	reader *strings.Reader
}

func (f fakeFile) Read(b []byte) (int, error) {
	return f.reader.Read(b)
}

func (f fakeFile) Close() error {
	return nil
}

func TestExtractMinSdk(t *testing.T) {
	tests := []struct {
		name           string
		manifests      []*strings.Reader
		defaultMinSdk  int
		expectedMinSdk int
	}{
		{
			name: "one manifest",
			manifests: []*strings.Reader{
				strings.NewReader(
					`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
		<uses-sdk android:minSdkVersion="20" />
</manifest>`)},
			defaultMinSdk:  14,
			expectedMinSdk: 20,
		},
		{
			name: "one manifest, lower then default min sdk",
			manifests: []*strings.Reader{
				strings.NewReader(
					`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
		<uses-sdk android:minSdkVersion="20" />
</manifest>`)},
			defaultMinSdk:  30,
			expectedMinSdk: 30,
		},
		{
			name: "multiple manifests",
			manifests: []*strings.Reader{
				strings.NewReader(
					`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
		<uses-sdk android:minSdkVersion="20" />
</manifest>`),
				strings.NewReader(
					`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
		<uses-sdk android:minSdkVersion="5" />
</manifest>`),
				strings.NewReader(
					`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
		<uses-sdk android:minSdkVersion="30" />
</manifest>`),
			},
			defaultMinSdk:  14,
			expectedMinSdk: 30,
		},
		{
			name: "multiple manifests, all lower than default min sdk",
			manifests: []*strings.Reader{
				strings.NewReader(
					`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
		<uses-sdk android:minSdkVersion="1" />
</manifest>`),
				strings.NewReader(
					`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
		<uses-sdk android:minSdkVersion="2" />
</manifest>`),
				strings.NewReader(
					`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
		<uses-sdk android:minSdkVersion="3" />
</manifest>`),
			},
			defaultMinSdk:  4,
			expectedMinSdk: 4,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			files := make([]io.ReadCloser, 0, len(tc.manifests))
			for _, f := range tc.manifests {
				file := fakeFile{reader: f}
				file.reader.Seek(0, 0)
				files = append(files, file)
			}
			minSdk, err := extractMinSdk(files, tc.defaultMinSdk)
			if err != nil {
				t.Fatalf("extractMinSdk(%v, %d) failed with err: %v", files, tc.defaultMinSdk, err)
			}
			if diff := cmp.Diff(tc.expectedMinSdk, minSdk); diff != "" {
				t.Errorf("extractMinSdkFromManifest(%v) returned diff (-want, +got):\n%v", files, diff)
			}
		})
	}

}

func TestExtractMinSdkFromManifest(t *testing.T) {
	tests := []struct {
		name           string
		manifest       *strings.Reader
		expectedMinSdk int
	}{
		{
			name: "minimal manifest",
			manifest: strings.NewReader(
				`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
		<uses-sdk android:minSdkVersion="1" />
		<application/>
</manifest>`),
			expectedMinSdk: 1,
		},
		{
			name: "manifest with placeholder",
			manifest: strings.NewReader(
				`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
		<uses-sdk android:minSdkVersion="${minSdkVersion}" />
		<application/>
</manifest>`),
			expectedMinSdk: 0,
		},
		{
			name: "empty manifest",
			manifest: strings.NewReader(
				`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
</manifest>`),
			expectedMinSdk: 0,
		},
		{
			name: "manifest with various elements",
			manifest: strings.NewReader(
				`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="com.default">
    <uses-permission android:name="android.permission.INTERNET" />
		<application android:label="@string/app_name"
			android:name="com.default.SomeApp"
			android:icon="@drawable/some_icon"
			android:theme="@style/a_theme"
			android:banner="@drawable/banner">
		<service android:name="com.default.MyService"
            android:exported="true">
            <intent-filter>
                <action android:name="com.default.IntentFilter" />
            </intent-filter>
        </service>
		</application>
		<uses-sdk android:minSdkVersion="25" />
</manifest>`),
			expectedMinSdk: 25,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			file := fakeFile{reader: tc.manifest}
			file.reader.Seek(0, 0)
			results := make(chan result)
			go func(results chan result) {
				res := extractMinSdkFromManifest(file)
				results <- res
			}(results)
			result := <-results
			if result.err != nil {
				t.Fatalf("extractMinSdkFromManifest(%v) failed with err: %v", file, result.err)
			}
			if diff := cmp.Diff(tc.expectedMinSdk, result.minSdk); diff != "" {
				t.Errorf("extractMinSdkFromManifest(%v) returned diff (-want, +got):\n%v", file, diff)
			}
		})
	}

}
