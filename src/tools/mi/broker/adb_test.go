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

package adb

import (
	"context"
	"fmt"
	"reflect"
	"testing"
)

func TestSetupEnv(t *testing.T) {
	t.Setenv("PATH", t.TempDir())
	tcs := []struct {
		name             string
		env              []string
		adbPath          string
		toolchainADBPath string
		wantPath         string
		wantEnv          []string
	}{
		/*
			Following test cases fail due to the os.stat check need refactor
			setupEnv method
			{
				name:     "NoArgsFallbackToDefaultADB",
				env:      nil,
				wantPath: defaultADB,
				wantEnv:  nil,
			}, {
				name:         "SpecifyADBTurboPath",
				env:          nil,
				adbTurboPath: "/my/adbturbo",
				wantPath:     "/my/adbturbo",
				wantEnv:      []string{androidADBVar + defaultADB},
			},
		*/{
			name:     "SpecifyADBPath",
			adbPath:  "/my/adb",
			wantPath: "/my/adb",
		}, {
			name:     "SpecifyADBPathViaEnv",
			env:      []string{androidADBVar + "/my/adb"},
			wantPath: "/my/adb",
			wantEnv:  []string{}, // Expect the env entry to be removed, which produces an empty list.
		}, {
			name:             "SpecifyADBPathOverridesEnvAndToolchain",
			env:              []string{androidADBVar + "/env/adb"},
			adbPath:          "/flag/adb",
			toolchainADBPath: "/toolchain/adb",
			wantPath:         "/flag/adb",
		}, {
			name:             "SpecifyADBPathViaEnvOverridesToolchain",
			env:              []string{androidADBVar + "/env/adb"},
			toolchainADBPath: "/toolchain/adb",
			wantPath:         "/env/adb",
		}, {
			name:             "SpecifyADBPathViaToolchain",
			toolchainADBPath: "/toolchain/adb",
			wantPath:         "/toolchain/adb",
		},
	}
	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			ae, err := setupEnv(context.Background(), tc.env, tc.adbPath, tc.toolchainADBPath)
			if err != nil {
				t.Fatalf("error occurred, got: %v", err)
			}
			if ae.Path != tc.wantPath {
				t.Errorf("path mismatch, got: %s wanted: %s", ae.Path, tc.wantPath)
			}
			if !(len(tc.wantEnv) == 0 && len(ae.env) == 0) && !reflect.DeepEqual(ae.env, tc.wantEnv) {
				t.Errorf("env mismatch,\ngot:\n%s\nwanted:\n%s", ae.env, tc.wantEnv)
			}
		})
	}
}

func TestADBRun(t *testing.T) {
	tcs := []struct {
		name    string
		wantErr bool
	}{
		{
			name: "RunSuccess",
		}, {
			name:    "RunError",
			wantErr: true,
		},
	}
	ctx := context.Background()
	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			mockRunner := func(context.Context, *ADB, ...string) ([]byte, []byte, error) {
				if tc.wantErr {
					return nil, nil, fmt.Errorf("error requested")
				}
				return nil, nil, nil
			}
			adb := &ADB{runner: mockRunner}
			o, e, err := adb.run(ctx)
			if err != nil {
				if tc.wantErr {
					return
				}
				t.Errorf("error occurred, got error: %s\nstdout:\n%s\nstderr:\n%s", err, string(o), string(e))
			}
		})
	}
}

func TestADBDevices(t *testing.T) {
	tcs := []struct {
		name             string
		adbDevices       string
		wantDevices      []string
		wantUnauthorized []string
		wantErr          bool
	}{
		{
			name: "OneDevice",
			adbDevices: `
List of devices attached
127.0.0.1:60001	device
`,
			wantDevices: []string{"127.0.0.1:60001"},
		}, {
			name: "MultipleDevice",
			adbDevices: `
List of devices attached
127.0.0.1:60001	device
00c6c53n48a73xb9	device
`,
			wantDevices: []string{"127.0.0.1:60001", "00c6c53n48a73xb9"},
		}, {
			name: "UnauthorizedDevice",
			adbDevices: `
List of devices attached
00d75d1a2333l1b0	unauthorized
`,
			wantUnauthorized: []string{"00d75d1a2333l1b0"},
		}, {
			name: "NoDevices",
			adbDevices: `
List of devices attached
`,
		}, {
			name:    "ErrorCallingDevices",
			wantErr: true,
		},
	}
	ctx := context.Background()
	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			mockRunner := func(context.Context, *ADB, ...string) ([]byte, []byte, error) {
				if tc.wantErr {
					return nil, nil, fmt.Errorf("error requested")
				}
				return []byte(tc.adbDevices), nil, nil
			}

			adb := &ADB{runner: mockRunner}
			devices, unauthorized, err := adb.devices(ctx)
			if err != nil {
				if tc.wantErr {
					return
				}
				t.Errorf("Unexpected error occurred, got error: %v", err)
			}
			if !reflect.DeepEqual(devices, tc.wantDevices) {
				t.Errorf("devices mismatch, got: %s wanted: %s", devices, tc.wantDevices)
			}
			if !reflect.DeepEqual(unauthorized, tc.wantUnauthorized) {
				t.Errorf("unauthorized mismatch, got: %s wanted: %s", unauthorized, tc.wantUnauthorized)
			}
		})
	}
}

func TestControllerExec(t *testing.T) {
	tcs := []struct {
		name        string
		cmd         string
		args        []string
		adbOut      string
		wantRunArgs []string
		wantOut     string
		wantErr     bool
	}{
		{
			name:   "QuotesDollarSignComponent",
			cmd:    "am",
			args:   []string{"start", "-a", "android.intent.action.MAIN", "-n", "com.example/.Shell$HomeActivity"},
			adbOut: "Starting: Intent { cmp=com.example/.Shell$HomeActivity }\nret=0\n",
			wantRunArgs: []string{
				"-s", "127.0.0.1:60001", "shell",
				"am 'start' '-a' 'android.intent.action.MAIN' '-n' 'com.example/.Shell$HomeActivity'; echo ret=$?",
			},
			wantOut: "Starting: Intent { cmp=com.example/.Shell$HomeActivity }",
		},
		{
			name:   "EscapesSingleQuoteInArg",
			cmd:    "echo",
			args:   []string{"a'b"},
			adbOut: "a'b\nret=0\n",
			wantRunArgs: []string{
				"-s", "127.0.0.1:60001", "shell",
				`echo 'a'\''b'; echo ret=$?`,
			},
			wantOut: "a'b",
		},
		{
			name:   "NonZeroReturnCode",
			cmd:    "cmd",
			args:   []string{"package", "resolve-activity", "com.example"},
			adbOut: "Unknown command\nret=1\n",
			wantRunArgs: []string{
				"-s", "127.0.0.1:60001", "shell",
				"cmd 'package' 'resolve-activity' 'com.example'; echo ret=$?",
			},
			wantOut: "Unknown command",
			wantErr: true,
		},
	}
	ctx := context.Background()
	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			var gotRunArgs []string
			mockRunner := func(_ context.Context, _ *ADB, args ...string) ([]byte, []byte, error) {
				gotRunArgs = args
				return []byte(tc.adbOut), nil, nil
			}
			ctl := &Controller{
				ADB:          &ADB{runner: mockRunner},
				DeviceSerial: "127.0.0.1:60001",
			}
			gotOut, _, err := ctl.Exec(ctx, tc.cmd, tc.args, true)
			if (err != nil) != tc.wantErr {
				t.Fatalf("Exec() error = %v, wantErr %v", err, tc.wantErr)
			}
			if !reflect.DeepEqual(gotRunArgs, tc.wantRunArgs) {
				t.Errorf("Exec() run args = %q, want %q", gotRunArgs, tc.wantRunArgs)
			}
			if gotOut != tc.wantOut {
				t.Errorf("Exec() stdout = %q, want %q", gotOut, tc.wantOut)
			}
		})
	}
}
