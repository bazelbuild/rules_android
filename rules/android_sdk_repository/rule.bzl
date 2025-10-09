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

load(
    "//rules:android_revision.bzl",
    "compare_android_revisions",
    "is_android_revision",
    "parse_android_revision",
)

_SDK_REPO_TEMPLATE = Label(":template.bzl")
_EMPTY_SDK_REPO_TEMPLATE = Label(":empty.template.bzl")

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

def sdk_package(
        linux_url = None,
        linux_sha256 = None,
        darwin_url = None,
        darwin_sha256 = None,
        windows_url = None,
        windows_sha256 = None,
        strip_prefix = None,
        add_prefix = None):
    """Creates a dictionary for an SDK package for multiple platforms.

    Args:
        linux_url: The download URL for the Linux package.
        linux_sha256: The SHA256 checksum for the Linux package.
        darwin_url: The download URL for the Darwin (macOS) package.
        darwin_sha256: The SHA256 checksum for the Darwin (macOS) package.
        windows_url: The download URL for the Windows package.
        windows_sha256: The SHA256 checksum for the Windows package.
        strip_prefix: A directory prefix to strip from the extracted files.
        add_prefix: A directory prefix to add to the output path.

    Returns:
        A dictionary formatted for the android_sdk_repository rule.
    """
    package = {}
    if linux_url:
        if not linux_sha256:
            fail("linux_sha256 must be provided with linux_url")
        package["linux_url"] = linux_url
        package["linux_sha256"] = linux_sha256
    if darwin_url:
        if not darwin_sha256:
            fail("darwin_sha256 must be provided with darwin_url")
        package["darwin_url"] = darwin_url
        package["darwin_sha256"] = darwin_sha256
    if windows_url:
        if not windows_sha256:
            fail("windows_sha256 must be provided with windows_url")
        package["windows_url"] = windows_url
        package["windows_sha256"] = windows_sha256
    if strip_prefix:
        package["strip_prefix"] = strip_prefix
    if add_prefix:
        package["add_prefix"] = add_prefix
    return package

def _read_api_levels(repo_ctx, android_sdk_path):
    platforms_dir = "%s/%s" % (android_sdk_path, _PLATFORMS_DIR)
    api_levels = []
    platforms_path = repo_ctx.path(platforms_dir)
    if not platforms_path.exists:
        return api_levels
    for entry in platforms_path.readdir():
        name = entry.basename
        if name.startswith("android-"):
            level = name[len("android-"):]
            if level.isdigit():
                api_levels.append(int(level))
    return api_levels

def _newest_build_tools(repo_ctx, android_sdk_path):
    build_tools_dir = "%s/%s" % (android_sdk_path, _BUILD_TOOLS_DIR)
    highest = None
    build_tools_path = repo_ctx.path(build_tools_dir)
    if not build_tools_path.exists:
        return None
    for entry in build_tools_path.readdir():
        name = entry.basename
        if is_android_revision(name):
            revision = parse_android_revision(name)
            highest = compare_android_revisions(highest, revision)
    return highest

def _find_system_images(repo_ctx, android_sdk_path):
    system_images_dir = "%s/%s" % (android_sdk_path, _SYSTEM_IMAGES_DIR)
    system_images = []

    system_images_path = repo_ctx.path(system_images_dir)
    if not system_images_path.exists:
        return system_images

    # The directory structure needed is "system-images/android-API/apis-enabled/arch"
    for api_entry in system_images_path.readdir():
        for enabled_entry in api_entry.readdir():
            for arch_entry in enabled_entry.readdir():
                image_path = "%s/%s/%s/%s" % (
                    _SYSTEM_IMAGES_DIR,
                    api_entry.basename,
                    enabled_entry.basename,
                    arch_entry.basename,
                )
                system_images.append(image_path)

    return system_images

def _get_platform_key(repo_ctx):
    os_name = repo_ctx.os.name.lower()
    if "linux" in os_name:
        return "linux"
    if "mac os x" in os_name:
        return "darwin"
    if "windows" in os_name:
        return "windows"
    fail("Unsupported operating system: " + repo_ctx.os.name)

def _configure_sdk_repository(repo_ctx, android_sdk_path):
    """Common logic for configuring the Android SDK repository."""

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

    # Write the build file.
    repo_ctx.symlink(Label(":helper.bzl"), "helper.bzl")
    repo_ctx.template(
        "BUILD.bazel",
        _SDK_REPO_TEMPLATE,
        substitutions = {
            "__repository_name__": repo_ctx.name,
            "__build_tools_version__": build_tools.version,
            "__build_tools_directory__": build_tools.dir,
            "__api_levels__": ",".join([str(level) for level in api_levels]),
            "__default_api_level__": str(default_api_level),
            "__system_image_dirs__": "\n".join(["'%s'," % d for d in system_images]),
            # TODO(katre): implement these.
            #"__exported_files__": "",
        },
    )

    # repo is reproducible
    return None

def _sandboxed_android_sdk_repository_impl(repo_ctx):
    platform_key = _get_platform_key(repo_ctx)

    sdk_packages = {
        "build_tools": _BUILD_TOOLS_DIR,
        "cmdline_tools": "cmdline-tools",
        "emulator": "emulator",
        "ndk": "ndk",
        "platform_tools": "platform-tools",
        "platforms": _PLATFORMS_DIR,
    }
    for attr_name, output_dir in sdk_packages.items():
        attr_value = getattr(repo_ctx.attr, attr_name)
        url_key = platform_key + "_url"
        sha256_key = platform_key + "_sha256"
        if url_key not in attr_value:
            fail("Missing URL for package '{}' on platform '{}'".format(attr_name, platform_key))

        output_path = output_dir
        add_prefix = attr_value.get("add_prefix")
        if add_prefix:
            output_path = output_path + "/" + add_prefix

        repo_ctx.download_and_extract(
            url = attr_value[url_key],
            sha256 = attr_value[sha256_key],
            output = output_path,
            stripPrefix = attr_value.get("strip_prefix", ""),
        )

    return _configure_sdk_repository(repo_ctx, "./")

_sandboxed_android_sdk_repository = repository_rule(
    implementation = _sandboxed_android_sdk_repository_impl,
    attrs = {
        "api_level": attr.int(default = 0),
        "build_tools_version": attr.string(),
        "build_tools": attr.string_dict(mandatory = True),
        "cmdline_tools": attr.string_dict(mandatory = True),
        "emulator": attr.string_dict(mandatory = True),
        "ndk": attr.string_dict(mandatory = True),
        "platform_tools": attr.string_dict(mandatory = True),
        "platforms": attr.string_dict(mandatory = True),
    },
    local = True,
)

def sandboxed_android_sdk_repository(
        name,
        build_tools,
        cmdline_tools,
        emulator,
        ndk,
        platform_tools,
        platforms,
        api_level = 0,
        build_tools_version = ""):
    """Create a repository with Android SDK toolchains.

    This rule downloads the Android SDK components from the provided URLs.

    Args:
      name: The repository name.
      build_tools: A dictionary with "url" and "sha256" for the build tools.
      cmdline_tools: A dictionary with "url" and "sha256" for the command-line tools.
      emulator: A dictionary with "url" and "sha256" for the emulator.
      ndk: A dictionary with "url" and "sha256" for the NDK.
      platform_tools: A dictionary with "url" and "sha256" for the platform tools.
      platforms: A dictionary with "url" and "sha256" for the platforms.
      api_level: The SDK API level to use.
      build_tools_version: The build_tools in the SDK to use.
    """

    _sandboxed_android_sdk_repository(
        name = name,
        build_tools = build_tools,
        cmdline_tools = cmdline_tools,
        emulator = emulator,
        ndk = ndk,
        platform_tools = platform_tools,
        platforms = platforms,
        api_level = api_level,
        build_tools_version = build_tools_version,
    )

    native.register_toolchains("@%s//:sdk-toolchain" % name)
    native.register_toolchains("@%s//:all" % name)

def _android_sdk_repository_impl(repo_ctx):
    # Determine the SDK path to use, either from the attribute or the environment.
    android_sdk_path = repo_ctx.attr.path
    if not android_sdk_path:
        android_sdk_path = repo_ctx.os.environ.get("ANDROID_HOME")
    if not android_sdk_path:
        # Create an empty repository that allows non-Android code to build.
        repo_ctx.template("BUILD.bazel", _EMPTY_SDK_REPO_TEMPLATE)
        return None
    if android_sdk_path.startswith("$WORKSPACE_ROOT"):
        android_sdk_path = str(repo_ctx.workspace_root) + android_sdk_path.removeprefix("$WORKSPACE_ROOT")

    # Symlink the needed contents to this repository.
    for dir_to_link in _DIRS_TO_LINK:
        source = "%s/%s" % (android_sdk_path, dir_to_link)
        dest = dir_to_link
        repo_ctx.symlink(source, dest)

    return _configure_sdk_repository(repo_ctx, android_sdk_path)

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

def android_sdk_repository(
        name,
        path = "",
        api_level = 0,
        build_tools_version = ""):
    """Create a repository with Android SDK toolchains.

    The SDK will be located at the given path, or via the ANDROID_HOME
    environment variable if the path attribute is unset.

    Args:
      name: The repository name.
      api_level: The SDK API level to use.
      build_tools_version: The build_tools in the SDK to use.
      path: The path to the Android SDK.
    """

    _android_sdk_repository(
        name = name,
        path = path,
        api_level = api_level,
        build_tools_version = build_tools_version,
    )

    native.register_toolchains("@%s//:sdk-toolchain" % name)
    native.register_toolchains("@%s//:all" % name)

def _android_sdk_repository_extension_impl(module_ctx):
    root_modules = [m for m in module_ctx.modules if m.is_root and m.tags.configure]
    if len(root_modules) > 1:
        fail("Expected at most one root module, found {}".format(", ".join([x.name for x in root_modules])))

    if root_modules:
        module = root_modules[0]
    else:
        module = module_ctx.modules[0]

    kwargs = {}
    if module.tags.configure:
        kwargs["api_level"] = module.tags.configure[0].api_level
        kwargs["build_tools_version"] = module.tags.configure[0].build_tools_version
        kwargs["path"] = module.tags.configure[0].path

    _android_sdk_repository(
        name = "androidsdk",
        **kwargs
    )

android_sdk_repository_extension = module_extension(
    implementation = _android_sdk_repository_extension_impl,
    tag_classes = {
        "configure": tag_class(attrs = {
            "path": attr.string(),
            "api_level": attr.int(),
            "build_tools_version": attr.string(),
        }),
    },
)
