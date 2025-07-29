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

// Package adb represents the "adb" version of the broker tools, compatible with API 15+.
package adb

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"src/common/golang/pprint"
)

var (
	checkFilePath = filepath.Join(os.TempDir(), "adbcheck")
)

const (
	defaultADB        = "/usr/bin/adb"
	adbCheckPeriod    = 2 * time.Hour
	androidADBVar     = "ANDROID_ADB="
	adbServerPortVar  = "ANDROID_ADB_SERVER_PORT"
	pushRetryAttempts = 3
)

type runner func(context.Context, *ADB, ...string) ([]byte, []byte, error)

func cmdRunner(ctx context.Context, adb *ADB, args ...string) ([]byte, []byte, error) {
	var stdOut, stdErr bytes.Buffer
	cmd := exec.CommandContext(ctx, adb.Path, append(adb.args, args...)...)
	cmd.Env = append(os.Environ(), adb.env...)
	cmd.Stdout = &stdOut
	cmd.Stderr = &stdErr
	err := cmd.Run()
	return stdOut.Bytes(), stdErr.Bytes(), err
}

// ADB is a wrapper around the ADB command line tool. It knows which adb server to connect.
type ADB struct {
	Path   string
	env    []string // Snapshot of the environment that ADB runs in.
	args   []string // Args that are passed to adb before the command, like -P.
	runner runner
}

func (a *ADB) run(ctx context.Context, args ...string) ([]byte, []byte, error) {
	return a.runner(ctx, a, args...)
}

func (a *ADB) init(ctx context.Context, useADBRoot bool) error {
	if o, e, err := a.run(ctx, "start-server"); err != nil {
		return fmt.Errorf("failed to start adb %v - %s - %s", err, string(o), string(e))
	}
	// Attempt to run `adb root`, and ignore any errors. We want to use root
	// if available but if not we will continue in non-root mode.
	if useADBRoot {
		a.run(ctx, "root")
	}
	return nil
}

func (a *ADB) devices(ctx context.Context) ([]string, []string, error) {
	stdOut, stdErr, err := a.run(ctx, "devices")
	if err != nil {
		return nil, nil, fmt.Errorf("error occurred while finding devices, got: %s\nstdout:\n%s\nstderr:\n%s", err, stdOut, stdErr)
	}

	// Parse the standard out for list of devices, apply a simple parse.
	//
	// Following is an example of the standard out from an "adb devices" invocation:
	//
	//     $ adb devices
	//     List of devices attached
	//     127.0.0.1:60001 device
	//
	// See test for more examples.
	var devices, unauthorized []string
	for _, l := range strings.Split(string(stdOut), "\n") {
		switch {
		case strings.HasSuffix(l, "device"):
			devices = append(devices, strings.TrimSpace(strings.TrimSuffix(l, "device")))
		case strings.HasSuffix(l, "unauthorized"):
			unauthorized = append(devices, strings.TrimSpace(strings.TrimSuffix(l, "unauthorized")))
		}
	}
	return devices, unauthorized, nil
}

// Controller is a device.Controller for adb connected devices.
type Controller struct {
	*ADB
	DeviceSerial string
}

func (a *Controller) run(ctx context.Context, args ...string) ([]byte, []byte, error) {
	return a.ADB.run(ctx, append(a.deviceArgs(), args...)...)
}

func (a *Controller) deviceArgs() []string {
	if a.DeviceSerial == "e" || a.DeviceSerial == "d" {
		return []string{"-" + a.DeviceSerial}
	}
	return []string{"-s", a.DeviceSerial}
}

// Exec executes the command in the shell of the specified device. The shell param is ignored and always assumed to be true
func (a *Controller) Exec(ctx context.Context, cmd string, args []string, shell bool) (string, string, error) {
	fullArgs := []string{"shell", cmd + " " + strings.Join(args, " ") + "; echo ret=$?"}
	oB, eB, err := a.run(ctx, fullArgs...)
	o := string(oB)
	e := string(eB)

	if err == nil {
		r := o[strings.LastIndex(o, "ret="):]
		o = strings.TrimSpace(o[:len(o)-len(r)])
		ret, convErr := strconv.Atoi(strings.TrimSpace(r[4:]))
		if convErr != nil {
			err = fmt.Errorf("error parsing return code %v", r)
		} else if ret != 0 {
			err = fmt.Errorf("non-zero return code '%d' from %s", ret, "adb shell "+cmd+" "+strings.Join(args, " "))
		}
	}
	return o, e, err
}

// Install installs the the split apk(s) in the device.
func (a *Controller) Install(ctx context.Context, args []string, apks ...string) error {

	bytes := int64(0)
	for _, p := range apks {
		fi, err := os.Stat(p)
		if err == nil { // Skip any errors for our logging purposes
			bytes += fi.Size()
		}
	}
	pprint.Info("Updating %.1f MB across %d split(s)", float64(bytes)/float64(1024*1024), len(apks))

	pushCtx, pushCancel := context.WithCancel(ctx)
	defer pushCancel()

	go func(ctx context.Context) {
		base := "Installing"
		nDots := 3
		for {
			select {
			case <-ctx.Done():
				return
			case <-time.After(5 * time.Second):
				pprint.Info(base + strings.Repeat(".", nDots))
				nDots = (nDots + 1) % 40
			}
		}
	}(pushCtx)

	fullArgs := append([]string{"install-multiple"}, args...)
	fullArgs = append(fullArgs, apks...)
	oB, eB, err := a.run(ctx, fullArgs...)
	o := string(oB)
	e := string(eB)
	if err != nil {
		return fmt.Errorf("got adb error running %s:\n%s\n%s", "adb "+strings.Join(args, " "), o, e)
	}
	return nil
}

// Push pushes an object from host to the device.
func (a *Controller) Push(ctx context.Context, from, to string) error {
	errStr := ""
	for i := 0; i < pushRetryAttempts; i++ {
		errStr = ""
		if o, e, err := a.run(ctx, "push", from, to); err != nil {
			errStr = fmt.Sprintf("error pushing %s to %s, got: %s %s %v", from, to, o, e, err)
			// Break early if permission issue
			if strings.Contains(strings.ToLower(string(o)+string(e)), "not permitted") {
				errStr += "\n\nTry running `adb root` then retry this command"
				break
			}
			pprint.Warning("pushing %s attempt %d/%d failed, retrying...", from, i+1, pushRetryAttempts)
			continue
		}
		break
	}
	if errStr != "" {
		return errors.New(errStr)
	}
	return nil
}

// Pull pulls an object from the device to the host.
func (a *Controller) Pull(ctx context.Context, from, to string) error {
	if o, e, err := a.run(ctx, "pull", from, to); err != nil {
		return fmt.Errorf("error pulling %s to %s, got: %s %s %v", from, to, o, e, err)
	}
	return nil
}

// setupEnv determines which adb path to use and sets up the implicit environment settings required
// and returns a prepared environment and the correct adb path.
func setupEnv(ctx context.Context, env []string, adbPath string) (*ADB, error) {
	adbSource := "default"

	// Find ANDROID_ADB entry from environment vars, if found set it as the path unless overridden.
	adbEnv := &ADB{}
	for _, entry := range env {
		if strings.HasPrefix(entry, androidADBVar) {
			adbEnv.Path = strings.TrimPrefix(entry, androidADBVar)
			adbSource = "environment variable"
			break
		}
	}

	// If ANDROID_ADB not found, try using adb from the user's path
	if adbEnv.Path == "" {
		path, _ := exec.LookPath("adb")
		if path != "" {
			adbEnv.Path = path
			adbSource = "path"
		}
	}

	// The flag should always win
	if adbPath != "" {
		adbEnv.Path = adbPath
		adbSource = "flag"
	}

	// Fallback to default pre-installed adb, if it exists, or fail if not found.
	if adbEnv.Path == "" {
		if _, err := os.Stat(defaultADB); err != nil {
			return nil, errors.New("unable to find ADB, please set the ANDROID_ADB environment variable or use the --adb flag")
		}
		adbEnv.Path = defaultADB
		adbSource = "fallback"
	}

	pprint.Info("Using ADB from %s: %s", adbSource, adbEnv.Path)
	return adbEnv, nil
}

// New creates a new adb Controller.
// If more than once device is available, deviceFlag must be specified.
func New(ctx context.Context, env []string, deviceSerial, adbPort, adbPath string, useADBRoot bool) (*Controller, error) {
	a, err := setupEnv(ctx, env, adbPath)
	if err != nil {
		return nil, err
	}

	// Setup additional adb args.
	var args []string
	if adbPort != "" {
		a.args = append(args, "-P", adbPort)
	}
	a.runner = cmdRunner

	if err := a.init(ctx, useADBRoot); err != nil {
		return nil, fmt.Errorf("unable to init adb client: %s", err.Error())
	}
	if deviceSerial == "" {
		devices, unauthorized, err := a.devices(ctx)
		if err != nil {
			return nil, fmt.Errorf("unable to get device list: %s", err.Error())
		}
		if len(devices) == 0 {
			var errMsg strings.Builder
			errMsg.WriteString("no available devices")
			if len(unauthorized) > 0 {
				errMsg.WriteString(", but found the following unauthorized device(s): ")
				fmt.Fprintf(&errMsg, "%v", unauthorized)
			}
			return nil, fmt.Errorf(errMsg.String())
		}
		if len(devices) > 1 {
			return nil, fmt.Errorf("more than one attached device available. Specify one with --device\n%s", devices)
		}
		deviceSerial = devices[0]
	}
	return &Controller{a, deviceSerial}, nil
}
