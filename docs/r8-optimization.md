# Shrinking and Optimization with R8

This page covers how to configure code shrinking, resource shrinking, bytecode
optimization, and obfuscation using **R8** with `rules_android`.

_If you're new to building Android apps with Bazel, start with the [Android App
Tutorial](https://bazel.build/start/android-app)._

## Overview

Android builds use
**[R8](https://developer.android.com/topic/performance/app-optimization/keep-rules-overview)**
to reduce application size, decrease runtime memory usage, and improve
performance. By eliminating unused code and resources, R8 reduces both the
on-device download size and the runtime memory footprint of your application.

R8 performs four core functions during the build process:

*   **Code shrinking (tree shaking):** Detects and safely removes unused
    classes, fields, methods, and attributes from your app and its library
    dependencies, reducing DEX size and runtime memory consumption.
*   **Resource shrinking:** Removes unused resources (such as drawables,
    layouts, and strings) packaged in your app. Resource shrinking works in
    tandem with code shrinking to reduce on-disk and in-memory asset overhead.
*   **Bytecode optimization:** Analyzes and optimizes bytecode instructions to
    reduce DEX code size and improve runtime efficiency on the Android
    Runtime (ART).
*   **Obfuscation (name minification):** Renames classes, fields, and methods
    with short, obfuscated names (such as `a`, `b`, `c`), reducing DEX file size
    and making reverse engineering more difficult.

Note that while R8 is the modern tool used under the hood (replacing
**ProGuard**), configuration attributes in `android_binary` and
`android_application` rules still retain the `proguard_` prefix (such as
`proguard_specs` and `proguard_generate_mapping`) for historical compatibility
with ProGuard configuration rule syntax.

## Configuring R8 in `android_binary` and `android_application`

R8 is enabled and configured using attributes on the
[`android_binary`](https://bazelbuild.github.io/rules_android/#android_binary)
rule (to produce an APK) or the
[`android_application`](https://bazelbuild.github.io/rules_android/#android_application)
rule (to produce an Android App Bundle / AAB). Both rules accept the same R8
optimization attributes.

### Key attributes

*   `proguard_specs`: A list of labels pointing to ProGuard/R8 configuration
    files containing keep rules and optimization directives. Specifying this
    attribute enables R8 code shrinking and optimization. Typically, this
    includes:
*   [`proguard-android-optimize.txt`](https://github.com/bazelbuild/examples/tree/main/android/r8-optimized/proguard-android-optimize.txt):
    Contains standard recommended Android app optimizations and default keep
    rules (equivalent to the default configuration provided by the Android
    Gradle Plugin). You can download it from the example repository and place it
    in your project.
*   `proguard-rules.pro`: An empty file where you add custom keep rules
    specific to your app, following the guide on [adding keep
    rules](https://developer.android.com/topic/performance/app-optimization/add-keep-rules).
*   `shrink_resources`: A boolean indicating whether to enable resource
    shrinking. When set to `True`, unused Android resources are removed from the
    packaged APK or AAB. *Note: Resource shrinking requires `proguard_specs` to
    be enabled.*
*   `proguard_generate_mapping`: A boolean indicating whether Bazel should
    generate a mapping file (`_proguard.map`) that maps obfuscated class and
    method names back to their original source names. This is essential for
    de-obfuscating crash stack traces in production.

### Recommended target structure

Because R8 optimization increases build times, a best practice is to declare a
separate optimized target for release builds while using an unoptimized target
during daily iterative development.

The following example `BUILD` configuration can be added directly to the
[Android App Tutorial](https://bazel.build/start/android-app) project in
`src/main/BUILD`:

```starlark
load("@rules_android//rules:rules.bzl", "android_binary")

# Unoptimized target for faster local build time and testing
android_binary(
    name = "app",
    manifest = "//src/main/java/com/example/bazel:AndroidManifest.xml",
    deps = ["//src/main/java/com/example/bazel:greeter_activity"],
)

# Optimized target for release and performance testing
android_binary(
    name = "r8-optimized-app",
    manifest = "//src/main/java/com/example/bazel:AndroidManifest.xml",
    proguard_generate_mapping = True,
    proguard_specs = [
        "proguard-android-optimize.txt",
        "proguard-rules.pro",
    ],
    shrink_resources = True,
    deps = ["//src/main/java/com/example/bazel:greeter_activity"],
)
```

## Configuring keep rules

R8 inspects all reachable entry points in your application. However, code or
resources accessed dynamically at runtime (such as via reflection, JNI native
methods, or XML layout references) might appear unused to static analysis and
could be stripped or renamed inadvertently.

To prevent R8 from removing or obfuscating required code, define **keep rules**
in your `proguard-rules.pro` file (initially created as an empty file alongside
your `BUILD` file). For detailed instructions and best practices, see the
official Android guide on
[how to add keep rules](https://developer.android.com/topic/performance/app-optimization/add-keep-rules).

### Common keep rule examples

```
# Preserve a class and all its public/protected methods and fields
-keep class com.example.bazel.model.** {
    public protected *;
}

# Preserve class members accessed via reflection
-keepclassmembers class com.example.bazel.data.UserData {
    <fields>;
}

# Preserve native JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Suppress warnings from third-party dependencies with incomplete references
-dontwarn com.example.thirdparty.**
```

## Building and inspecting outputs

Run the following command to build the optimized binary:

```bash
bazel build //path/to:r8-optimized-app
```

### Build outputs

Bazel places build artifacts in the `bazel-bin` output directory:

*   **Optimized APK or AAB:** `bazel-bin/path/to/r8-optimized-app.apk` (or
    `.aab` when using `android_application`), containing the shrunk and
    optimized app.
*   **ProGuard Mapping File:** `bazel-bin/path/to/r8-optimized-app_proguard.map`
    (generated when `proguard_generate_mapping = True`), containing mapping data
    for stack trace de-obfuscation.
*   **Optional diagnostic files:** Diagnostic files such as seeds and usage
    lists indicating which classes and members were kept or removed can
    optionally be configured via flags in `proguard-rules.pro`, e.g.
    `-printseeds <file>` and `-printusage <file>`.

### App size impact

For small sample applications, the difference in APK or AAB size between
unoptimized and optimized builds may be minimal. However, as an application
grows and incorporates larger third-party dependencies (such as Guava, AndroidX,
or gRPC), R8's tree shaking and resource shrinking can significantly reduce the
final download and install size.

## Troubleshooting & testing

If you encounter issues or unexpected behavior when running your R8-optimized
app, refer to the following R8 guides:

*   [Troubleshoot the
    optimization](https://developer.android.com/topic/performance/app-optimization/troubleshoot-the-optimization)
    – General guidance on diagnosing shrinking and optimization issues.
*   [Troubleshooting
    rules](https://developer.android.com/topic/performance/app-optimization/troubleshooting-rules)
    – Instructions on debugging and fixing missing keep rules.
*   [Test the
    optimization](https://developer.android.com/topic/performance/app-optimization/test-the-optimization)
    – Best practices for validating and testing optimized builds before
    publishing.

## Further reading

*   [Android App Tutorial](https://bazel.build/start/android-app) – Step-by-step
    walkthrough of building Android apps with Bazel.
*   [Fast Iterative Development with mobile-install](https://bazel.build/docs/mobile-install)
    – Accelerate Android development cycles.
*   [Android R8 Keep Rules
    Overview](https://developer.android.com/topic/performance/app-optimization/keep-rules-overview)
    – Official Android guide to customizing R8 rules.
*   [Adding Keep Rules
    Guide](https://developer.android.com/topic/performance/app-optimization/add-keep-rules)
    – Detailed guide on authoring custom keep rules for your application.
*   [rules_android Stardoc](https://bazelbuild.github.io/rules_android/) – API
    and attribute documentation for rules_android.
