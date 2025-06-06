To build, ensure that the `ANDROID_HOME` environment variable is set to the path
to an Android SDK, and run:

```
bazel build app:assets
```

This will build application bundle containing a dynamic feature containing assets (named assets.txt). Verify with :

```
jar -tf bazel-bin/app/assets_unsigned.aab | grep assets.txt
```
