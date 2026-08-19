# R8 Optimized Android App Example

This example demonstrates how to build and optimize a simple Android application using **R8**.

## What is R8 and Why Use It?

[R8](https://developer.android.com/build/shrink-code) is the code shrinker, optimizer, and dexer for Android developed by Google. In a single step, R8 handles:

- **Code Shrinking (Tree Shaking)**: Detects and safely removes unused classes, methods, fields, and attributes from your application and third-party dependencies.
- **Code Optimization**: Inspects and rewrites code to improve runtime performance, inline methods, remove dead branches, and eliminate unused arguments.
- **Name Obfuscation**: Renames types and members with short names to minimize DEX size.
- **Resource Shrinking**: When paired with `shrink_resources = True`, removes unused Android resources that are no longer referenced after code shrinking.
- **Dexing**: Directly converts Java bytecode to optimized Android DEX format.

Using R8 significantly reduces APK/AAB download and install sizes and memory footprint, decreases app startup time, and keeps method counts within optimal limits.

For in-depth details on configuring ProGuard/R8 keep rules and optimization flags, see [docs/r8-optimization.md](../../docs/r8-optimization.md).

## Building the Targets

Ensure that the `ANDROID_HOME` environment variable is set to the path of your Android SDK:

```bash
export ANDROID_HOME=/path/to/android/sdk
```

### 1. Build the Optimized APK (`android_binary`)

To build the standalone optimized APK:

```bash
bazel build //:r8_app
```

Output: `bazel-bin/r8_app.apk`

### 2. Build the Optimized Android App Bundle (`android_application`)

To build the optimized Android App Bundle (AAB):

```bash
bazel build //:r8_app_bundle
```

Output: `bazel-bin/r8_app_bundle_unsigned.aab`

### 3. Fast Incremental Installation with Mobile-Install

To build and install the application directly onto a connected Android device or running emulator:

```bash
bazel mobile-install //:r8_app
```

## Configuration Files

- **`BUILD`**: Defines the `android_binary` (`r8_app`) and `android_application` (`r8_app_bundle`) targets with `proguard_specs` and `shrink_resources = True`.
- **`proguard-rules.pro`**: App-specific keep rules for preserving entry points like `MainActivity`.
- **`proguard-android-optimize.txt`**: Default Android optimization rules for R8.
- **`.bazelrc`**: Flags and settings needed to build the app with `rules_android`.