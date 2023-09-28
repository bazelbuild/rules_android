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

// The deploy_binary command unpacks a workspace and deploys it to a device.
package main

import (
	"context"
	"flag"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"

	glog "github.com/golang/glog"

	_ "src/common/golang/flagfile"
	"src/common/golang/flags"
	"src/common/golang/pprint"
	"src/tools/mi/deployment_oss/deployment"
)

var (
	adbArgs        = flags.NewStringList("adb_arg", "Options for the adb binary.")
	adbPath        = flag.String("adb", "/usr/bin/adb", "Path to the adb binary to use with mobile-install.")
	device         = flag.String("device", "", "The adb device serial number.")
	javaHome       = flag.String("java_home", "", "Path to JDK.")
	launchActivity = flag.String("launch_activity", "", "Activity to launch via am start -n package/.activity_to_launch.")
	appPackagePath = flag.String("manifest_package_name_path", "", "Path to file containing the manifest package name.")
	splits         = flags.NewStringList("splits", "The list of split apk paths.")
	start          = flag.String("start", "", "start_type from mobile-install.")
	startType      = flag.String("start_type", "", "start_type (deprecated, use --start).")
	useADBRoot     = flag.Bool("use_adb_root", true, "whether (true) or not (false) to use root permissions.")
	userID         = flag.Int("user", 0, "User id to install the app for.")

	// Studio deployer args
	studioDeployerPath = flag.String("studio_deployer", "", "Path to the Android Studio deployer.")
	optimisticInstall  = flag.Bool("optimistic-install", false, "If true, try to push changes to the device without installing.")
	studioVerboseLog   = flag.Bool("studio-verbose-log", false, "If true, enable verbose logging for the Android Studio deployer")

	// Need to double up on launch_app due as the built-in flag module does not support noXX for bool flags.
	// Some users are using --nolaunch_app, so we need to explicitly declare this flag
	launchApp   = flag.Bool("launch_app", true, "Launch the app after the sync is done.")
	noLaunchApp = flag.Bool("nolaunch_app", false, "Don't launch the app after the sync is done.")
	noDeploy    = flag.Bool("nodeploy", false, "Don't deploy or launch the app, useful for testing.")

	// Unused flags: Relevant only for Google-internal use cases, but need to exist in the flag parser
	buildID = flag.String("build_id", "", "The id of the build. Set by Bazel, the user should not use this flag.")
)

func resolveDeviceSerialAndPort(ctx context.Context, device string) (deviceSerialFlag, port string) {
	switch {
	case strings.Contains(device, ":tcp:"):
		parts := strings.SplitN(device, ":tcp:", 2)
		deviceSerialFlag = parts[0]
		port = parts[1]
	case strings.HasPrefix(device, "tcp:"):
		port = strings.TrimPrefix(device, "tcp:")
	default:
		deviceSerialFlag = device
	}
	return deviceSerialFlag, port
}

func determineDeviceSerial(deviceSerialFlag, deviceSerialEnv, deviceSerialADBArg string) string {
	var deviceSerial string
	switch {
	case deviceSerialFlag != "":
		deviceSerial = deviceSerialFlag
	case deviceSerialEnv != "":
		deviceSerial = deviceSerialEnv
	case deviceSerialADBArg != "":
		deviceSerial = deviceSerialADBArg
	}
	return deviceSerial
}

// ReadFile reads file from a given path
func readFile(path string) []byte {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		log.Fatalf("Error reading file %q: %v", path, err)
	}
	return data
}

func parseRepeatedFlag(n string, a *flags.StringList) {
	var l []string
	for _, f := range os.Args {
		if strings.HasPrefix(f, n) {
			l = append(l, strings.TrimPrefix(f, n))
		}
	}
	if len(l) > 1 {
		*a = l
	}
}

// Flush all the metrics to Streamz before the program exits.
func flushAndExitf(ctx context.Context, unused1, unused2, unused3, unused4, format string, args ...any) {
	glog.Exitf(format, args...)
}

func main() {
	ctx := context.Background()

	flag.Parse()

	pprint.Info("Deploying using OSS mobile-install!")

	if *noDeploy {
		pprint.Warning("--nodeploy set, not deploying application.")
		return
	}

	// Override --launch_app if --nolaunch_app is passed
	if *noLaunchApp {
		*launchApp = false
	}

	if *appPackagePath == "" {
		glog.Exitf("--manifest_package_name is required")
	}

	// Resolve the device serial and port.
	var deviceSerialFlag, port string
	if *device != "" {
		deviceSerialFlag, port = resolveDeviceSerialAndPort(ctx, *device)
	}
	deviceSerialEnv := os.Getenv("ANDROID_SERIAL")

	// TODO(b/66490815): Remove once adb_arg flag is deprecated.
	// Check for a device serial in adb_arg. If deviceSerial has not been specified, the value
	// found here will become the deviceSerial. If the deviceSerial has been specified the value
	// found here will be ignored but we will notify the user the device chosen.
	var deviceSerialADBArg string
	for i, arg := range *adbArgs {
		if strings.TrimSpace(arg) == "-s" && len(*adbArgs) > i+1 {
			deviceSerialADBArg = (*adbArgs)[i+1]
		}
	}

	// TODO(timpeut): Delete after the next blaze release
	// Ignore the device passed by --adb_arg if it matches the device passed by --device.
	if deviceSerialADBArg == *device {
		deviceSerialADBArg = ""
	}

	// Determine which value to use as the deviceSerial.
	deviceSerial := determineDeviceSerial(deviceSerialFlag, deviceSerialEnv, deviceSerialADBArg)

	// Warn user of the multiple device serial specification, that is not equal to the first.
	if (deviceSerialEnv != "" && deviceSerialEnv != deviceSerial) ||
		(deviceSerialADBArg != "" && deviceSerialADBArg != deviceSerial) {
		pprint.Warning("A device serial was specified more than once with --device, $ANDROID_SERIAL or --adb_arg, using %s.", deviceSerial)
	}

	appPackage := strings.TrimSpace(string(readFile(*appPackagePath)))

	startTime := time.Now()

	pprint.Info("Installing application using the Android Studio deployer ...")
	if err := deployment.AndroidStudioSync(ctx, deviceSerial, port, appPackage, *splits, *studioDeployerPath, *adbPath, *javaHome, *optimisticInstall, *studioVerboseLog, *userID, *useADBRoot); err != nil {
		flushAndExitf(ctx, "", "", "", "", "Got error installing using the Android Studio deployer: %v", err)
	}

	deploymentTime := time.Since(startTime)
	pprint.Info("Took %.2f seconds to sync changes", deploymentTime.Seconds())

	if *startType != "" {
		*start = *startType
	}

	// Wait for the debugger if debug mode selected
	if *start == "DEBUG" {
		waitCmd := exec.Command(*adbPath, "shell", "am", "set-debug-app", "-w", appPackage)
		if err := waitCmd.Wait(); err != nil {
			pprint.Error("Unable to wait for debugger: %s", err.Error())
		}
	}

	if *launchApp {
		pprint.Info("Finished deploying changes. Launching app")
		var launchCmd *exec.Cmd
		if *launchActivity != "" {
			launchCmd = exec.Command(*adbPath, "shell", "am", "start", "-a", "android.intent.action.MAIN", "-n", appPackage+"/"+*launchActivity)
		} else {
			launchCmd = exec.Command(*adbPath, "shell", "monkey", "-p", appPackage, "1")
			pprint.Warning(
				"No or multiple main activities found, falling back to Monkey launcher. Specify the activity you want with `-- --launch_activity` or `-- --nolaunch_app` to launch nothing.")
		}

		if err := launchCmd.Run(); err != nil {
			pprint.Warning("Unable to launch app. Specify an activity with --launch_activity.")
			pprint.Warning("Original error: %s", err.Error())
		}
	} else {
		// Always stop the app since classloader needs to be reloaded.
		stopCmd := exec.Command(*adbPath, "shell", "am", "force-stop", appPackage)
		if err := stopCmd.Run(); err != nil {
			pprint.Error("Unable to stop app: %s", err.Error())
		}
	}
}
