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

// Unit tests for the AndroidManifest tool that to enforce a floor on the minSdkVersion attribute.

package minsdkfloor

import (
	"bytes"
	"testing"
)

var (
	ManifestNoUsesSdk = []byte(`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example">
</manifest>
`)

	ManifestNoMinSdk = []byte(`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example">
<uses-sdk/>
</manifest>
`)

	ManifestMinSdkPlaceholder = []byte(`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example">
<uses-sdk android:minSdkVersion="${minSdkVersion}"/>
</manifest>
`)

	ManifestMinSdk = []byte(`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example">
<uses-sdk android:minSdkVersion="12"/>
</manifest>
`)

	ManifestMinSdkUpdated = []byte(`<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example">
<uses-sdk android:minSdkVersion="24"/>
</manifest>
`)

	ManifestMinSdkComment = []byte(`<?xml version="1.0" encoding="utf-8"?><!--
External comment
-->
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example">
<!-- Internal comment -->
<uses-sdk android:minSdkVersion="12"/>
</manifest>
`)

	ManifestMinSdkCommentUpdated = []byte(`<?xml version="1.0" encoding="utf-8"?><!--
External comment
-->
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example">
<!-- Internal comment -->
<uses-sdk android:minSdkVersion="24"/>
</manifest>
`)

	ManifestNoUsesSdkWithComment = []byte(`<?xml version="1.0" encoding="utf-8"?><!--
External comment
-->
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example">
</manifest>
`)
	ManifestNoUsesSdkWithCommentUpdated = []byte(`<?xml version="1.0" encoding="utf-8"?><!--
External comment
-->
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example">
<uses-sdk android:minSdkVersion="24"/>
</manifest>
`)
)

func TestBumpMinSdkFloor(t *testing.T) {

	testCases := []struct {
		name     string
		sdk      int
		input    []byte
		expected []byte
	}{
		{"Add uses-sdk tag when missing", 24, ManifestNoUsesSdk, ManifestMinSdkUpdated},
		{"Add minSdkVersion attribute when missing", 24, ManifestNoMinSdk, ManifestMinSdkUpdated},
		{"No change when newSdk is not specified", 0, ManifestNoUsesSdk, ManifestNoUsesSdk},
		{"No change when minSdkVersion uses placeholder", 24, ManifestMinSdkPlaceholder, ManifestMinSdkPlaceholder},
		{"Bump minSdkVersion", 24, ManifestMinSdk, ManifestMinSdkUpdated},
		{"Noop when minSdkVersion is greater and given sdk", 11, ManifestMinSdk, ManifestMinSdk},
		{"Bump minSdkVersion and keep comments", 24, ManifestMinSdkComment, ManifestMinSdkCommentUpdated},
		{"Add uses-sdk tag when missing and preserve comments.", 24, ManifestNoUsesSdkWithComment, ManifestNoUsesSdkWithCommentUpdated},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {

			manifest, _, err := BumpMinSdk(tc.input, tc.sdk)
			if err != nil {
				t.Fatal(err)
			}

			if !bytes.Equal(manifest, tc.expected) {
				t.Errorf("Updated XML doesn't match expected:\nGot:\n%s\nExpected:\n%s", manifest, tc.expected)
			}
		})
	}
}

func TestSetDefaultMinSdkFloor(t *testing.T) {

	testCases := []struct {
		name     string
		sdk      string
		input    []byte
		expected []byte
	}{
		{"Add uses-sdk tag when missing", "24", ManifestNoUsesSdk, ManifestMinSdkUpdated},
		{"Add minSdkVersion attribute when missing", "24", ManifestNoMinSdk, ManifestMinSdkUpdated},
		{"No change when newSdk is not specified", "", ManifestNoUsesSdk, ManifestNoUsesSdk},
		{"No change when minSdkVersion uses placeholder", "24", ManifestMinSdkPlaceholder, ManifestMinSdkPlaceholder},
		{"No change when minSdkVersion is defined", "24", ManifestMinSdk, ManifestMinSdk},
		{"Add uses-sdk tag when missing and preserve comments.", "24", ManifestNoUsesSdkWithComment, ManifestNoUsesSdkWithCommentUpdated},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {

			manifest, _, err := SetDefaultMinSdk(tc.input, tc.sdk)
			if err != nil {
				t.Fatal(err)
			}

			if !bytes.Equal(manifest, tc.expected) {
				t.Errorf("Updated XML doesn't match expected:\nGot:\n%s\nExpected:\n%s", manifest, tc.expected)
			}
		})
	}
}
