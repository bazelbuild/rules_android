
# Android Bazel Roadmap

This document describes the major release milestones for the Android Bazel
Rules. There are three major pillars that we are focused on when developing the
Android rules - **Performance**, **Features**, and **Developer Experience** -
and for each milestone we list the main items for each pillar. Progress on each
item is tracked via an issue.

If you have feedback on this roadmap (including feature and reprioritization
requests) please open an issue or comment on the existing one.

## Rules Alpha (est. mid 2019)

The primary goal of the Rules Alpha release is to start collecting feedback from
projects and developers that are interested in being early adopters of the
rules. Our intention is for Rules Alpha to be a 1:1 identical drop-in
replacement for the native Android rules, although undoubtedly there will be
missing features and we cannot always guarantee 100% backwards compatibility.

### Performance

*   Use AAPT2 for resource processing
*   Use D8 for Dexing

### Features

*   Support android_instrumentation_test on macOS
*   Support building and testing on Google Cloud Platform Remote Build Execution
*   Support new Android App Bundle format
*   Accept APKs directly into android_instrumentation_test
*   Simplified package and dependency management
*   Improve Kotlin interoperability
*   Integration with Bazel's platforms and toolchains support
*   Modern and correct NDK support

### Developer Experience

*   Documentation for Android with Bazel compatibility across Windows, macOS,
    Linux
*   Documentation for Android with Bazel compatibility across Android Studio
    versions
*   Stable and reliable CI
*   NDK documentation and samples

## Rules Beta (est. late 2019)

The goal for the Rules Beta release is to provide a stable, (mostly) feature
complete version of the rules for all developers and projects. We intend the
Rules Beta release to be the first version of the rules to be broadly adopted,
and will comply with Bazel's backwards compatibility guarantees.

### Performance

*   Improve resource processing speed and incrementality
*   Decouple Java compilation from R.class generation
*   Launch Bazel mobile-install v2

### Features

*   New android_application rule for app packaging / sourceless binary /
    android_application
*   Improved support for AAR creation
*   Support Databinding 3.4.0 (v2)
*   Support `bazel coverage` for all test rules
*   Integration with Android Lint

### Developer Experience

*   Document best practices
*   Best in class tutorials and migration guides
