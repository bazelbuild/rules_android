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

package device

import (
	"context"
	"errors"
	"fmt"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
)

type mockController struct {
	mockExec func(ctx context.Context, cmd string, args []string) (string, string, error)
}

func (*mockController) Push(context.Context, string, string) error {
	return nil
}

func (*mockController) Pull(context.Context, string, string) error {
	return nil
}

func (m *mockController) Exec(ctx context.Context, cmd string, args []string, shell bool) (string, string, error) {
	if m.mockExec == nil {
		return "", "", nil
	}
	return m.mockExec(ctx, cmd, args)
}

func (m *mockController) Install(ctx context.Context, args []string, apks ...string) error {
	return nil
}

func TestGetProp(t *testing.T) {
	for _, tt := range []struct {
		name         string
		execResponse string
		wantProps    map[string]string
		execErr      bool
		wantErr      bool
	}{
		{
			name:      "Empty",
			wantProps: map[string]string{},
		},
		{
			name:         "OneProp",
			wantProps:    map[string]string{abiListProp: "x86"},
			execResponse: "[ro.product.cpu.abilist]: [x86]\n",
		},
		{
			name:         "TwoProps",
			wantProps:    map[string]string{abiListProp: "x86", sdkProp: "23"},
			execResponse: "[ro.product.cpu.abilist]: [x86]\n[ro.build.version.sdk]: [23]\n",
		},
		{
			name:         "MultilineProp",
			wantProps:    map[string]string{"ro.multiline.property": "some text\nsome more text\n", sdkProp: "23"},
			execResponse: "[ro.multiline.property]: [\nsome text\nsome more text\n]\n[ro.build.version.sdk]: [23]\n",
		},
	} {
		t.Run(tt.name, func(t *testing.T) {
			mockExec := func(context.Context, string, []string) (string, string, error) {
				if tt.execErr {
					return "", "", fmt.Errorf("error requested")
				}
				return tt.execResponse, "", nil
			}
			props, err := getProp(context.Background(), &mockController{mockExec: mockExec})
			if err != nil {
				if !tt.wantErr {
					t.Errorf("unexpected error %v", err)
				}
			} else {
				if diff := cmp.Diff(props, tt.wantProps); diff != "" {
					t.Errorf("got props different than want props: %s", diff)
				}
			}
		})
	}

}

func TestParseResolvedActivity(t *testing.T) {
	for _, tt := range []struct {
		name    string
		out     string
		want    string
		wantErr error
	}{
		{
			name: "SingleLauncherActivity",
			out:  "priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=false\ncom.example/.MainActivity\n",
			want: "com.example/.MainActivity",
		},
		{
			name: "ActivityWithDollarSign",
			out:  "priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=false\ncom.example/.app.honeycomb.Shell$HomeActivity\n",
			want: "com.example/.app.honeycomb.Shell$HomeActivity",
		},
		{
			name: "FullyQualifiedActivity",
			out:  "priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=false\r\ncom.example/com.other.MainActivity\r\n",
			want: "com.example/com.other.MainActivity",
		},
		{
			name:    "NoActivity",
			out:     "No activity found\n",
			wantErr: errNoLauncherActivity,
		},
		{
			name:    "MultipleActivities",
			out:     "priority=0 preferredOrder=0 match=0x0 specificIndex=-1 isDefault=false\nandroid/com.android.internal.app.ResolverActivity\n",
			wantErr: errMultipleLauncherActivities,
		},
		{
			name:    "OtherPackage",
			out:     "com.example.other/.MainActivity\n",
			wantErr: errMultipleLauncherActivities,
		},
		{
			name:    "UnexpectedOutput",
			out:     "Error: Unknown option: --brief\n",
			wantErr: cmpopts.AnyError,
		},
		{
			name:    "Empty",
			out:     "",
			wantErr: cmpopts.AnyError,
		},
	} {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseResolvedActivity(tt.out, "com.example")
			if !cmp.Equal(err, tt.wantErr, cmpopts.EquateErrors()) {
				t.Fatalf("parseResolvedActivity() error = %v, want %v", err, tt.wantErr)
			}
			if got != tt.want {
				t.Errorf("parseResolvedActivity() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestLauncherWarningReason(t *testing.T) {
	for _, tt := range []struct {
		err  error
		want string
	}{
		{err: errNoLauncherActivity, want: "No launcher activity found"},
		{err: errMultipleLauncherActivities, want: "Multiple launcher activities found"},
		{err: fmt.Errorf("resolve-activity failed: %v", errors.New("non-zero return code")), want: "Unable to determine the launcher activity"},
	} {
		if got := launcherWarningReason(tt.err); got != tt.want {
			t.Errorf("launcherWarningReason(%v) = %q, want %q", tt.err, got, tt.want)
		}
	}
}

func TestLaunch(t *testing.T) {
	const pkg = "com.example"
	for _, tt := range []struct {
		name        string
		activity    string
		resolveOut  string
		resolveErr  bool
		wantCommand []string
	}{
		{
			name:        "ExplicitActivity",
			activity:    ".SomeActivity",
			wantCommand: []string{"am", "start", "-a", "android.intent.action.MAIN", "-n", "com.example/.SomeActivity"},
		},
		{
			name:        "ExplicitActivityWithDollarSign",
			activity:    ".app.honeycomb.Shell$HomeActivity",
			wantCommand: []string{"am", "start", "-a", "android.intent.action.MAIN", "-n", "com.example/.app.honeycomb.Shell$HomeActivity"},
		},
		{
			name:        "ResolvedLauncherActivity",
			resolveOut:  "priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=false\ncom.example/.MainActivity\n",
			wantCommand: []string{"am", "start", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", "-n", "com.example/.MainActivity"},
		},
		{
			name:        "ResolvedLauncherActivityWithDollarSign",
			resolveOut:  "priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=false\ncom.example/.app.honeycomb.Shell$HomeActivity\n",
			wantCommand: []string{"am", "start", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", "-n", "com.example/.app.honeycomb.Shell$HomeActivity"},
		},
		{
			name:        "NoLauncherActivityFallsBackToMonkey",
			resolveOut:  "No activity found\n",
			wantCommand: []string{"monkey", "-p", "com.example", "1"},
		},
		{
			name:        "ResolveFailureFallsBackToMonkey",
			resolveErr:  true,
			wantCommand: []string{"monkey", "-p", "com.example", "1"},
		},
	} {
		t.Run(tt.name, func(t *testing.T) {
			var launchCommand []string
			mockExec := func(_ context.Context, cmd string, args []string) (string, string, error) {
				switch {
				case cmd == "am" && args[0] == "force-stop":
					return "", "", nil
				case cmd == "cmd" && args[0] == "package":
					if tt.resolveErr {
						return "", "Unknown command", fmt.Errorf("non-zero return code")
					}
					return tt.resolveOut, "", nil
				default:
					if launchCommand != nil {
						t.Errorf("unexpected second launch command %q after %q", append([]string{cmd}, args...), launchCommand)
					}
					launchCommand = append([]string{cmd}, args...)
					return "Starting: Intent { ... }", "", nil
				}
			}
			d := &Device{Ctl: &mockController{mockExec: mockExec}}
			if err := d.Launch(context.Background(), pkg, tt.activity); err != nil {
				t.Fatalf("Launch() returned unexpected error: %v", err)
			}
			if diff := cmp.Diff(tt.wantCommand, launchCommand); diff != "" {
				t.Errorf("Launch() ran unexpected command (-want +got):\n%s", diff)
			}
		})
	}
}
