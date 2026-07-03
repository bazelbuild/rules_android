# Fat AAR Rules

This directory contains the implementation of the `fat_aar` rule and supporting utilities for bundling multiple Android libraries into a single AAR file.

## Overview

The `fat_aar` rule consolidates multiple `android_library` targets and their transitive dependencies into a unified AAR package. This is useful for:

- **Simplified distribution**: Publish a single AAR instead of managing multiple library dependencies
- **Dependency encapsulation**: Hide internal module structure from external consumers
- **Selective bundling**: Exclude external dependencies (e.g., Maven artifacts) while tracking them for POM generation

## Rules

### `fat_aar`

Bundles transitive `android_library` dependencies into a single AAR file.

**Defined in**: `rule.bzl`

**Key features**:
- Collects all transitive dependencies using aspects
- Bundles Java/Kotlin classes, resources, assets, manifests, native libraries, and ProGuard rules
- Filters dependencies based on exclusion patterns
- Generates excluded dependencies file as output group

**Examples**:

Basic usage:
```python
fat_aar(
    name = "my_fat_aar",
    deps = [":my_library"],
    exclude = ["@maven//", "@@maven//", "@@com_github_jetbrains_kotlin"],
    min_sdk_version = "23",
)
```

With R8 optimization:
```python
fat_aar(
    name = "my_fat_aar_optimized",
    deps = [":my_library"],
    exclude = ["@maven//", "@@maven//", "@@com_github_jetbrains_kotlin"],
    r8_config = "proguard.pro",
    min_sdk_version = "23",
)
```

**Attributes**:
- `deps` (required): List of `android_library` targets to bundle. All transitive dependencies will be included unless excluded via the `exclude` attribute
- `exclude` (optional, default: `[]`): List of label patterns to exclude from bundling. Commonly used to exclude external dependencies that consumers are expected to provide (e.g., `["@maven//", "@@maven//"]` to exclude all Maven dependencies, `"@@com_github_jetbrains_kotlin"` to exclude Kotlin stdlib)
- `min_sdk_version` (optional, default: `"23"`): Minimum SDK version for the primary manifest. This is used when merging multiple AndroidManifest.xml files
- `r8_config` (optional): ProGuard configuration file (`.pro` or `.txt`) for R8 optimization. If provided, R8 will optimize and shrink the bundled code. The configuration is combined with transitive ProGuard specs from all dependencies

**Outputs**:
- Default output: The bundled AAR file containing merged classes, resources, assets, manifests, native libraries, and ProGuard rules
- Output group `excluded_deps`: Text file listing all dependencies that were excluded (useful for POM generation)
- Output group `manifest`: The merged AndroidManifest.xml file
- Output group `class_jar`: The classes.jar file (optionally R8-optimized if `r8_config` is provided)

### `fat_aar_pom`

Generates a Maven POM file from a fat_aar's excluded dependencies.

**Defined in**: `pom_from_fat_aar.bzl`

**Key features**:
- Looks up excluded Bazel labels in Maven coordinates list
- Generates POM with proper dependency declarations
- Supports both 3-part and 4-part Maven coordinates

**Example**:
```python
fat_aar_pom(
    name = "my_pom",
    fat_aar = ":my_fat_aar",
    maven_coords = MAVEN_ARTIFACTS,
    group_id = "com.example",
    artifact_id = "my-library",
    version = "1.0.0",
)
```

**Attributes**:
- `fat_aar`: The `fat_aar` target to generate POM for
- `maven_coords`: List of all Maven coordinates (format: `"group:artifact:type:version"`)
- `group_id`: Maven group ID
- `artifact_id`: Maven artifact ID
- `version`: Maven version

## Supporting Files

### `aspect.bzl`

Defines the `fat_aar_aspect` and providers:

- **`FatAarInfo`**: Collects Android providers (resources, assets, manifests, native libs, ProGuard) as `(label, provider)` tuples for filtering
- **`FatAarDependenciesInfo`**: Tracks labels of excluded dependencies for POM generation

The aspect traverses the dependency graph and collects all Android-related providers from transitive dependencies.

### `add_native_libs.sh`

Shell script that adds native libraries to the AAR in the correct format.

**Why it's needed**:
- Android native libraries are distributed in ZIP files with `lib/ARCH/*.so` structure
- The AAR format requires `jni/ARCH/*.so` structure
- This script extracts native libs from ZIP files and converts them to AAR format

**Usage**: Called automatically by the `fat_aar` rule implementation.

## R8 Integration

When `r8_config` is provided, R8 runs with the following behavior:

- **Output format**: `.class` files (not `.dex`) using the `--classfile` flag
- **Library classpath**: Android SDK jar is provided via `--lib`
- **ProGuard configs**: Combines the user-provided `r8_config` with all transitive ProGuard specifications from dependencies
- **Optimization mode**: `--release` mode for production optimization
- **API level**: Note that `--min-api` is not supported when using `--classfile` mode

### R8 Configuration Best Practices

Create a ProGuard configuration file (e.g., `proguard.pro`):

```proguard
# Keep all public API
-keep public class * { public *; }

# Keep attributes for debugging
-keepattributes Exceptions,InnerClasses,Signature,SourceFile,LineNumberTable,EnclosingMethod

# Don't obfuscate (optional - use if you want readable class names)
-dontobfuscate

# Allow R8 to optimize
-allowaccessmodification

# Don't warn about excluded dependencies
-dontwarn kotlin.**
-dontwarn org.jetbrains.annotations.**
-dontwarn java.lang.invoke.LambdaMetafactory
```

**Key points**:
1. **Keep public API**: Use `-keep public class * { public *; }` to preserve your SDK's public interface
2. **Exclude warnings**: Add `-dontwarn` rules for dependencies you've excluded (e.g., Kotlin stdlib)
3. **Keep attributes**: Include `EnclosingMethod` attribute when keeping `InnerClasses`
4. **Don't obfuscate (optional)**: Use `-dontobfuscate` if you want readable class names in your SDK
5. **Allow optimization**: Use `-allowaccessmodification` to let R8 optimize more aggressively

## How It Works

1. **Dependency Collection**:
   - The `fat_aar_aspect` traverses the dependency graph
   - Collects Android providers as `(label, provider)` tuples
   - Allows filtering based on label patterns

2. **Filtering**:
   - Labels and files are checked against `exclude` patterns
   - Excluded labels are tracked in `FatAarDependenciesInfo` provider
   - Excluded dependencies list is generated as output group

3. **Bundling**:
   - Resources are merged from all included libraries
   - Manifests are merged using Android's manifest merger tool
   - Classes are combined into a single `classes.jar`
   - **R8 Optimization** (optional): If `r8_config` is provided, R8 optimizes and shrinks the merged classes
   - Native libraries are converted to AAR format
   - R.txt and ProGuard rules are merged

4. **POM Generation**:
   - Excluded labels are looked up in Maven coordinates list
   - Matching dependencies are added to POM
   - Generated POM can be used for Maven publishing

## Integration with Uber Repository

In the Uber Android monorepo, these rules are wrapped by the `uber_fat_aar` macro in `android/defs.bzl`, which:

- Creates the fat AAR with standard exclusions
- Wraps it with `aar_import` for consumption
- Generates POM file automatically
- Creates publish target for Maven/Artifactory

See `android/experimental/sample/simple/app_fat_aar/` for a complete example.

## File Structure

```
rules/fat_aar/
├── README.md                   # This file
├── BUILD                       # Exports scripts and bzl files
├── rule.bzl                    # fat_aar rule implementation
├── aspect.bzl                  # Aspect and providers
├── pom_from_fat_aar.bzl       # fat_aar_pom rule
└── add_native_libs.sh         # Native library conversion script
```

## See Also

- **Example**: `bazel_rules_android_legacy/examples/fat_aar/`
- **Uber integration**: `android/defs.bzl` (`uber_fat_aar` macro)
- **Publishing**: `android/rules/publish_aar/aar_publish.bzl`
- **Usage example**: `android/experimental/sample/simple/app_fat_aar/`
