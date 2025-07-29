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

// Package device provides functionality to interact with an android device.
package device

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"src/common/golang/pprint"
	"src/tools/mi/broker/adb"
)

const (
	abiProp              = "ro.product.cpu.abi"
	abiListProp          = "ro.product.cpu.abilist"
	buildDescriptionProp = "ro.build.description"
	sdkProp              = "ro.build.version.sdk"
)

// Controller exposes basic functionality to interact with a device.
type Controller interface {
	Install(ctx context.Context, args []string, apks ...string) error
	Exec(ctx context.Context, cmd string, args []string, shell bool) (stdOut, stdErr string, err error)
	Push(ctx context.Context, from, to string) error
	Pull(ctx context.Context, from, to string) error
}

// Device holds information of a particular android device.
type Device struct {
	Ctl      Controller
	abis     []string
	Props    map[string]string
	userOnce sync.Once
	APILevel int
	ABI      string
	ABIs     []string
	tmpDir   string
	user     string
}

// New creates and returns a new Device.
func New(ctx context.Context, deviceSerial, port, tmpDir string, adbPath string, useADBRoot bool) (*Device, error) {
	ctl, err := initDeviceController(ctx, adbPath, deviceSerial, port, useADBRoot)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize device controller %v", err)
	}
	props, err := getProp(ctx, ctl)
	if err != nil {
		return nil, fmt.Errorf("failed to get device properties. Confirm that your device is visible to `adb devices`, "+
			"and make sure to use Pontis for remote connections: %v", err)
	}
	a, ok := props[sdkProp]
	if !ok {
		return nil, errors.New("unable to get device API level")
	}
	apiLevel, err := strconv.Atoi(a)
	if err != nil {
		return nil, fmt.Errorf("could not parse device API level: %v", err)
	}
	abi := props[abiProp]
	if abi == "" {
		return nil, errors.New("unable to get ABIs from device")
	}
	abis := props[abiListProp]
	if abis == "" {
		return nil, errors.New("unable to get supported ABIs from device")
	}
	d := &Device{Ctl: ctl, tmpDir: tmpDir, APILevel: apiLevel, ABI: abi, ABIs: strings.Split(abis, ",")}
	return d, nil
}

// Stop stops the application with the provided package name
func (d *Device) Stop(ctx context.Context, manifestPackageName string) {
	d.Ctl.Exec(ctx, "am", []string{"force-stop", manifestPackageName}, false)
}

// Launch starts an app with a given activity.
func (d *Device) Launch(ctx context.Context, manifestPackageName, activity string) error {
	var err error
	var stdOut string
	var stdErr string
	d.Ctl.Exec(ctx, "am", []string{"force-stop", manifestPackageName}, false)
	if activity != "" {
		cmp := manifestPackageName + "/" + activity
		stdOut, stdErr, err = d.Ctl.Exec(
			ctx, "am", []string{"start", "-a", "android.intent.action.MAIN", "-n", cmp}, true)
	} else {
		stdOut, stdErr, err = d.Ctl.Exec(ctx, "am", []string{"start", manifestPackageName}, true)
		if err != nil || strings.Contains(stdOut+stdErr, "Error: ") {
			pprint.Warning(
				"No or multiple main activities found, falling back to Monkey launcher. Specify the activity you want with `-- --launch_activity` or `-- --nolaunch_app` to launch nothing.")
			stdOut, stdErr, err = d.Ctl.Exec(ctx, "monkey", []string{"-p", manifestPackageName, "1"}, true)
		}
	}
	if err == nil && strings.Contains(stdOut+stdErr, "Error: ") {
		err = errors.New(stdOut + stdErr)
	}
	return err
}

// WaitForDebugger sets up the application of the package main to be debuggable.
func (d *Device) WaitForDebugger(ctx context.Context, manifestPackageName string) {
	d.Ctl.Exec(ctx, "am", []string{"set-debug-app", "-w", manifestPackageName}, false)
}

// BuildDesc returns a human-readable description of the device build.
func (d *Device) BuildDesc() string {
	return d.Props[buildDescriptionProp]
}

func getProp(ctx context.Context, ctl Controller) (map[string]string, error) {
	var stdout string
	var err error
	for i := 0; i < 3; i++ {
		ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
		stdout, _, err = ctl.Exec(ctx, "getprop", []string{}, false)
		cancel()
		if err == nil {
			return parseProperties(stdout)
		}
	}
	return nil, err
}

func parseProperties(in string) (map[string]string, error) {
	s := bufio.NewScanner(strings.NewReader(in))

	props := map[string]string{}
	// output looks roughly like:
	// [someprop]: [its value]\n
	// [otherprop]: [val 2]\n
	// [init.svc.vold]: [running]\n
	// [anotherprop]: [val 3]\n
	for s.Scan() {
		l := s.Text()
		p := strings.Split(l, ":")
		if len(p) != 2 {
			continue
		}
		// p[0] looks like "[prop.name]"
		prop := p[0][1 : len(p[0])-1]
		var val string
		// Multiline value
		if strings.HasSuffix(p[1], "[") {
			var vb strings.Builder
			for s.Scan() {
				l = s.Text()
				if l == "]" {
					val = vb.String()
					break
				}
				vb.WriteString(l)
				vb.WriteString("\n")
			}
		} else {
			// Single line value
			val = p[1][2 : len(p[1])-1]
		}
		props[prop] = val
	}
	return props, nil
}

func initDeviceController(ctx context.Context, adbPath string, deviceSerial, port string, useADBRoot bool) (Controller, error) {
	var ctl Controller
	var err error
	ctl, err = adb.New(ctx, os.Environ(), deviceSerial, port, adbPath, useADBRoot)
	if err != nil {
		return nil, fmt.Errorf("Unable to connect to device: %v", err)
	}
	return ctl, nil
}
