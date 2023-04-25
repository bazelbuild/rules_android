# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Bazel rule for Android sdk repository."""

load("android_revision.bzl", "AndroidRevision", "compare_android_revisions", "parse_android_revision")

_SDK_REPO_TEMPLATE = Label("//rules:android_sdk_repository_template.txt")
_EMPTY_SDK_REPO_TEMPLATE = Label("//rules:android_sdk_repository_empty_template.txt")

_BUILD_TOOLS_DIR = "build-tools"
_PLATFORMS_DIR = "platforms"
_SYSTEM_IMAGES_DIR = "system-images"
_LOCAL_MAVEN_REPOS = [
    "extras/android/m2repository",
    "extras/google/m2repository",
    "extras/m2repository",
]
_DIRS_TO_LINK = [
    _BUILD_TOOLS_DIR,
    "emulator",
    "platform-tools",
    _PLATFORMS_DIR,
    _SYSTEM_IMAGES_DIR,
] + _LOCAL_MAVEN_REPOS

_MIN_BUILD_TOOLS_VERSION = parse_android_revision("30.0.0")

def _read_api_levels(repo_ctx, android_sdk_path):
    platforms_dir = "%s/%s" % (android_sdk_path, _PLATFORMS_DIR)
    api_levels = []
    for entry in repo_ctx.execute(["ls", platforms_dir]).stdout.splitlines():
        if entry.startswith("android-"):
            level = int(entry[len("android-"):])
            api_levels.append(level)

    return api_levels

def _newest_build_tools(repo_ctx, android_sdk_path):
    build_tools_dir = "%s/%s" % (android_sdk_path, _BUILD_TOOLS_DIR)
    highest = None
    for entry in repo_ctx.execute(["ls", build_tools_dir]).stdout.splitlines():
        revision = parse_android_revision(entry)
        highest = compare_android_revisions(highest, revision)
    return highest

def _find_system_images(repo_ctx, android_sdk_path):
    system_images_dir = "%s/%s" % (android_sdk_path, _SYSTEM_IMAGES_DIR)
    system_images = []

    # system image directories are typically "system-images/android-API/apis-enabled/arch"
    for entry in repo_ctx.execute(["find", system_images_dir, "-mindepth", "3", "-maxdepth", "3"]).stdout.splitlines():
        entry = entry[len(android_sdk_path) + 1:]
        system_images.append(entry)
    return system_images

def _find_local_maven_files(repo_ctx, android_sdk_path):
    # TODO(katre): implement this
    # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/bazel/rules/android/AndroidSdkRepositoryFunction.java;drc=818c5c8693c43fe490c9f6b2c05149eb8f45cf52;l=330
    for local_maven_dir in _LOCAL_MAVEN_REPOS:
        full_dir = "%s/%s" % (android_sdk_path, local_maven_dir)
        # Find .pom files
        # Parse each for aar and jar files.

    return []

def _android_sdk_repository_impl(repo_ctx):
    # Determine the SDK path to use, either from the attribute or the environment.
    android_sdk_path = repo_ctx.attr.path
    if not android_sdk_path:
        android_sdk_path = repo_ctx.os.environ.get("ANDROID_HOME")
    if not android_sdk_path:
        # Create an empty repository that allows non-Android code to build.
        repo_ctx.template("BUILD", _EMPTY_SDK_REPO_TEMPLATE)
        return None

    # Symlink the needed contents to this repository.
    for dir_to_link in _DIRS_TO_LINK:
        source = "%s/%s" % (android_sdk_path, dir_to_link)
        dest = dir_to_link
        repo_ctx.symlink(source, dest)

    # Read list of supported SDK levels
    api_levels = _read_api_levels(repo_ctx, android_sdk_path)
    if len(api_levels) == 0:
        fail("No Android SDK apis found in the Android SDK at %s. Please install APIs from the Android SDK Manager." % android_sdk_path)

    # Determine default SDK level.
    default_api_level = max(api_levels)
    if repo_ctx.attr.api_level:
        default_api_level = int(repo_ctx.attr.api_level)
    if default_api_level not in api_levels:
        fail("Android SDK api level %s was requested but it is not installed in the Android SDK at %s. The api levels found were %s. Please choose an available api level or install api level %s from the Android SDK Manager." % (
            default_api_level,
            android_sdk_path,
            api_levels,
            default_api_level,
        ))

    # Determine build_tools directory (and version)
    build_tools = None
    if repo_ctx.attr.build_tools_version:
        build_tools = parse_android_revision(repo_ctx.attr.build_tools_version)
    else:
        build_tools = _newest_build_tools(repo_ctx, android_sdk_path)

    # Check validity of build_tools
    if not build_tools:
        fail("Unable to determine build tools version")
    if compare_android_revisions(build_tools, _MIN_BUILD_TOOLS_VERSION) != build_tools:
        fail("Bazel requires Android build tools version %s or newer, %s was provided" % (
            _MIN_BUILD_TOOLS_VERSION.dir,
            build_tools.dir,
        ))

    # Determine system image dirs
    system_images = _find_system_images(repo_ctx, android_sdk_path)

    # Handle local maven files.
    local_maven_files = _find_local_maven_files(repo_ctx, android_sdk_path)
    #print("found %d local maven files" % len(local_maven_files))

    # Write the build file.
    repo_ctx.symlink(Label(":android_sdk_repository_template.bzl"), "android_sdk_repository_template.bzl")
    repo_ctx.template(
        "BUILD",
        _SDK_REPO_TEMPLATE,
        substitutions = {
            "%repository_name%": repo_ctx.name,
            "%build_tools_version%": build_tools.version,
            "%build_tools_directory%": build_tools.dir,
            "%api_levels%": ",".join([str(level) for level in api_levels]),
            "%default_api_level%": str(default_api_level),
            "%system_image_dirs%": "\n".join(["'%s'," % d for d in system_images]),
            # TODO(katre): implement these.
            "%exported_files%": "",
        },
    )

    # repo is reproducible
    return None

_android_sdk_repository = repository_rule(
    implementation = _android_sdk_repository_impl,
    attrs = {
        "api_level": attr.int(default = 0),
        "build_tools_version": attr.string(),
        "path": attr.string(),
    },
    environ = ["ANDROID_HOME"],
    local = True,
)

def _bind(repo_name, bind_name, target):
    native.bind(name = bind_name, actual = "@%s//%s" % (repo_name, target))

def android_sdk_repository(name, **kwargs):
    _android_sdk_repository(name = name, **kwargs)

    _bind(name, "android/sdk", ":sdk")
    _bind(name, "android/d8_jar_import", ":d8_jar_import")
    _bind(name, "android/dx_jar_import", ":dx_jar_import")
    _bind(name, "android_sdk_for_testing", ":files")
    _bind(name, "has_android_sdk", ":has_android_sdk")
    native.register_toolchains("@%s//:all" % name)
