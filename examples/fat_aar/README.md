# Fat AAR Example

This example demonstrates how to use the `fat_aar` rule to bundle multiple Android libraries and their transitive dependencies into a single AAR file.

## Structure

- **lib1**: Android library with resources, layouts, and assets
- **lib2**: Android library that depends on lib1 (demonstrates transitive bundling)
- **native_lib**: Native library (demonstrates native library bundling)

## Targets

### `bundled`
A fat AAR that bundles all transitive dependencies including:
- Java/Kotlin classes from lib1 and lib2
- Resources from all libraries
- Assets from all libraries
- Native libraries
- Merged AndroidManifest.xml

```bash
bazel build //examples/fat_aar:bundled
```

### `bundled_filtered`
A fat AAR with exclusions - demonstrates filtering out external dependencies:
```bash
bazel build //examples/fat_aar:bundled_filtered
```

## What Gets Bundled

The `fat_aar` rule automatically collects and bundles:

1. **Classes (classes.jar)**: All Java/Kotlin bytecode from transitive dependencies
2. **Resources (res/)**: All resources from transitive android_library targets
3. **Assets (assets/)**: All assets from transitive dependencies
4. **Native Libraries (jni/)**: Native .so files for all architectures
5. **AndroidManifest.xml**: Merged manifest from all libraries
6. **R.txt**: Combined R.txt for resource IDs
7. **proguard.txt**: Merged ProGuard rules

## Excluding Dependencies

Use the `exclude` attribute to filter out dependencies (e.g., external Maven dependencies):

```python
fat_aar(
    name = "my_aar",
    exclude = ["@maven//"],  # Exclude all Maven dependencies
    deps = [":my_lib"],
)
```

## Output

The fat AAR is a standard Android AAR file that can be:
- Published to Maven/Artifactory
- Consumed by other Android projects (Gradle or Bazel)
- Distributed as a reusable component
