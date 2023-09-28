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

// Package deployment has utilities to sync mobile-install build outputs with a device.
package deployment

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"

	"src/common/golang/pprint"
)

// AndroidStudioSync calls to the Studio deployer with splits.
func AndroidStudioSync(ctx context.Context, deviceSerial, port, pkg string, splits []string, deployer, adbPath, jdk string, optimisticInstall bool, studioVerboseLog bool, userID int, useADBRoot bool) error {
	args := []string{"-jar", deployer, "install", pkg}
	if deviceSerial != "" {
		args = append(args, fmt.Sprintf("--device=%s", deviceSerial))
	}
	args = append(args, "--skip-post-install", "--no-jdwp-client-support")
	if optimisticInstall {
		args = append(args, "--optimistic-install")
	}
	if useADBRoot {
		args = append(args, "--use-root-push-install")
	}
	if studioVerboseLog {
		args = append(args, "--log-level=VERBOSE")
	}
	if adbPath != "" {
		args = append(args, fmt.Sprintf("--adb=%s", adbPath))
	}
	if userID != 0 {
		args = append(args, fmt.Sprintf("--user=%s", strconv.Itoa(userID)))
	}
	args = append(args, splits...)
	cmd := exec.Command(jdk, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if port != "" {
		cmd.Env = append(os.Environ(), fmt.Sprintf("ANDROID_ADB_SERVER_PORT=%s", port))
	}
	if studioVerboseLog {
		pprint.Info("device: %s", deviceSerial)
		pprint.Info("port: %s", port)
		pprint.Info("Env: %s", cmd.Env)
		pprint.Info("Cmd: %s", cmd.String())
	}
	return cmd.Run()
}
