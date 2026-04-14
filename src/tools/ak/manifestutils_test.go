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

package manifestutils

import (
	"encoding/xml"
	"testing"
)

func TestLauncherActivity(t *testing.T) {
	tests := []struct {
		name         string
		manifestXML  string
		wantActivity string
	}{
		{
			name: "single launcher activity",
			manifestXML: `<?xml version="1.0" ?>
<manifest package="com.example.app" xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:name="android.app.Application">
    <activity android:name="com.example.app.MainActivity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>`,
			wantActivity: "com.example.app.MainActivity",
		},
		{
			name: "no launcher activity",
			manifestXML: `<?xml version="1.0" ?>
<manifest package="com.example.app" xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:name="android.app.Application">
    <activity android:name="com.example.app.MainActivity">
      <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
      </intent-filter>
    </activity>
  </application>
</manifest>`,
			wantActivity: "",
		},
		{
			name: "main without launcher category",
			manifestXML: `<?xml version="1.0" ?>
<manifest package="com.example.app" xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:name="android.app.Application">
    <activity android:name="com.example.app.MainActivity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.DEFAULT"/>
      </intent-filter>
    </activity>
  </application>
</manifest>`,
			wantActivity: "",
		},
		{
			name: "multiple activities, one is launcher",
			manifestXML: `<?xml version="1.0" ?>
<manifest package="com.example.app" xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:name="android.app.Application">
    <activity android:name="com.example.app.SettingsActivity">
      <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
      </intent-filter>
    </activity>
    <activity android:name="com.example.app.MainActivity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>`,
			wantActivity: "com.example.app.MainActivity",
		},
		{
			name: "no activities at all",
			manifestXML: `<?xml version="1.0" ?>
<manifest package="com.example.app" xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:name="android.app.Application"/>
</manifest>`,
			wantActivity: "",
		},
		{
			name: "activity with no intent filters",
			manifestXML: `<?xml version="1.0" ?>
<manifest package="com.example.app" xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:name="android.app.Application">
    <activity android:name="com.example.app.MainActivity"/>
  </application>
</manifest>`,
			wantActivity: "",
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			var manifest Manifest
			if err := xml.Unmarshal([]byte(test.manifestXML), &manifest); err != nil {
				t.Fatalf("xml.Unmarshal failed: %v", err)
			}
			got := manifest.LauncherActivity()
			if got != test.wantActivity {
				t.Errorf("LauncherActivity() = %q, want %q", got, test.wantActivity)
			}
		})
	}
}
