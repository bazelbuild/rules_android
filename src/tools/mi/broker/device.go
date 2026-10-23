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

	mainAction       = "android.intent.action.MAIN"
	launcherCategory = "android.intent.category.LAUNCHER"
)

var (
	errNoLauncherActivity         = errors.New("no launcher activity found")
	errMultipleLauncherActivities = errors.New("multiple launcher activities found")
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
	ADBPath  string
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
func New(ctx context.Context, deviceSerial, port, tmpDir string, adbPath, toolchainADBPath string, useADBRoot bool) (*Device, error) {
	ctl, err := initDeviceController(ctx, adbPath, toolchainADBPath, deviceSerial, port, useADBRoot)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize device controller %v", err)
	}
	selectedADBPath := ""
	if adbCtl, ok := ctl.(*adb.Controller); ok {
		selectedADBPath = adbCtl.Path
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
	d := &Device{Ctl: ctl, ADBPath: selectedADBPath, tmpDir: tmpDir, APILevel: apiLevel, ABI: abi, ABIs: strings.Split(abis, ",")}
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
			ctx, "am", []string{"start", "-a", mainAction, "-n", cmp}, true)
	} else if cmp, resolveErr := d.resolveLauncherActivity(ctx, manifestPackageName); resolveErr == nil {
		// `am start <package>` builds an implicit MAIN/LAUNCHER intent, which only resolves activities
		// that also declare CATEGORY_DEFAULT. Launcher activities usually don't, so resolve the
		// launcher activity explicitly and start it by component name, as the home screen does.
		stdOut, stdErr, err = d.Ctl.Exec(
			ctx, "am", []string{"start", "-a", mainAction, "-c", launcherCategory, "-n", cmp}, true)
	} else {
		pprint.Warning(
			"%s, falling back to Monkey launcher. Specify the activity you want with `-- --launch_activity` or `-- --nolaunch_app` to launch nothing.", launcherWarningReason(resolveErr))
		stdOut, stdErr, err = d.Ctl.Exec(ctx, "monkey", []string{"-p", manifestPackageName, "1"}, true)
	}
	if err == nil && strings.Contains(stdOut+stdErr, "Error: ") {
		err = errors.New(stdOut + stdErr)
	}
	return err
}

// resolveLauncherActivity returns the component name (e.g. "com.example/.MainActivity") of the
// activity that the home screen would launch for the given package.
func (d *Device) resolveLauncherActivity(ctx context.Context, manifestPackageName string) (string, error) {
	stdOut, stdErr, err := d.Ctl.Exec(ctx, "cmd", []string{
		"package", "resolve-activity", "--brief", "-c", launcherCategory, manifestPackageName}, true)
	if err != nil {
		return "", fmt.Errorf("resolve-activity failed: %v %s", err, stdErr)
	}
	return parseResolvedActivity(stdOut, manifestPackageName)
}

// parseResolvedActivity extracts the component name from the output of
// `cmd package resolve-activity --brief`, which looks like:
//
//	priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=false
//	com.example/.MainActivity
//
// If the package has no launcher activity the output is "No activity found", and errNoLauncherActivity
// is returned. If it has multiple, the intent resolves to the system chooser (e.g.
// "android/com.android.internal.app.ResolverActivity"), and errMultipleLauncherActivities is returned.
func parseResolvedActivity(out, manifestPackageName string) (string, error) {
	lines := strings.Split(strings.TrimSpace(out), "\n")
	cmp := strings.TrimSpace(lines[len(lines)-1])
	switch {
	case strings.HasPrefix(cmp, manifestPackageName+"/"):
		return cmp, nil
	case cmp == "No activity found":
		return "", errNoLauncherActivity
	case strings.Contains(cmp, "/") && !strings.ContainsAny(cmp, " \t"):
		// A component in another package: the system chooser.
		return "", errMultipleLauncherActivities
	default:
		return "", fmt.Errorf("unexpected resolve-activity output %q", strings.TrimSpace(out))
	}
}

// launcherWarningReason returns a short, user-facing explanation of why the launcher activity could
// not be resolved.
func launcherWarningReason(err error) string {
	switch {
	case errors.Is(err, errNoLauncherActivity):
		return "No launcher activity found"
	case errors.Is(err, errMultipleLauncherActivities):
		return "Multiple launcher activities found"
	default:
		return "Unable to determine the launcher activity"
	}
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

func initDeviceController(ctx context.Context, adbPath, toolchainADBPath string, deviceSerial, port string, useADBRoot bool) (Controller, error) {
	var ctl Controller
	var err error
	ctl, err = adb.New(ctx, os.Environ(), deviceSerial, port, adbPath, toolchainADBPath, useADBRoot)
	if err != nil {
		return nil, fmt.Errorf("Unable to connect to device: %v", err)
	}
	return ctl, nil
}
