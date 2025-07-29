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
	"fmt"
	"testing"

	"github.com/google/go-cmp/cmp"
)

type mockController struct {
	mockExec func(context.Context, []string) (string, string, error)
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
	return m.mockExec(ctx, args)
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
			mockExec := func(context.Context, []string) (string, string, error) {
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
