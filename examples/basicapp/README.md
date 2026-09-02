# Basic Android app

Set `ANDROID_HOME` to an Android SDK, then from this directory run:

```
bazel build //java/com/basicapp:basic_app
```

This example is a Bzlmod project (`MODULE.bazel`). The
`local_path_override` is only for rules_android presubmit; drop it when
copying the file into your own repo and depend on a released version from
the Bazel Central Registry instead (see the root README).

`.bazelrc` has the Java 17 and C++17 flags needed to build.
