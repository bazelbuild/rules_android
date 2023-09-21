# Copyright 2016 The Bazel Authors. All rights reserved.
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

"""Helpers for the build file used in android_sdk_repository."""

load("@local_config_platform//:constraints.bzl", "HOST_CONSTRAINTS")
load("@rules_java//java:defs.bzl", "java_binary", "java_import")

def _bool_flag_impl(_unused_ctx):
    pass

_bool_flag = rule(
    implementation = _bool_flag_impl,
    build_setting = config.bool(flag = True),
)

def _int_flag_impl(ctx):
    allowed_values = ctx.attr.values
    value = ctx.build_setting_value
    if len(allowed_values) != 0 and value not in ctx.attr.values:
        fail(
            "Error setting %s: invalid value '%d'. Allowed values are %s" % (
                ctx.label,
                value,
                ",".join([str(val) for val in allowed_values]),
            ),
        )

int_flag = rule(
    implementation = _int_flag_impl,
    build_setting = config.int(flag = True),
    attrs = {
        "values": attr.int_list(
            doc = "The list of allowed values for this setting. An error is raised if any other value is given.",
        ),
    },
    doc = "An int-typed build setting that can be set on the command line",
)

def _create_config_setting_rule():
    """Create config_setting rule for windows.

    These represent the matching --host_cpu values.
    """
    name = "windows"
    if not native.existing_rule(name):
        native.config_setting(
            name = name,
            values = {"host_cpu": "x64_" + name},
        )

    native.config_setting(
        name = "d8_standalone_dexer",
        values = {"define": "android_standalone_dexing_tool=d8_compat_dx"},
    )

    native.config_setting(
        name = "dx_standalone_dexer",
        values = {"define": "android_standalone_dexing_tool=dx_compat_dx"},
    )

    _bool_flag(
        name = "allow_proguard",
        build_setting_default = True,
    )

    native.config_setting(
        name = "disallow_proguard",
        flag_values = {":allow_proguard": "false"},
    )

def create_android_sdk_rules(
        name,
        build_tools_version,
        build_tools_directory,
        api_levels,
        default_api_level):
    """Generate android_sdk rules for the API levels in the Android SDK.

    Args:
      name: string, the name of the repository being generated.
      build_tools_version: string, the version of Android's build tools to use.
      build_tools_directory: string, the directory name of the build tools in
          sdk's build-tools directory.
      api_levels: list of ints, the API levels from which to get android.jar
          et al. and create android_sdk rules.
      default_api_level: int, the API level to alias the default sdk to if
          --android_sdk is not specified on the command line.
    """

    _create_config_setting_rule()

    int_flag(
        name = "api_level",
        build_setting_default = default_api_level,
        values = api_levels,
        visibility = ["//visibility:public"],
    )

    windows_only_files = [
        "build-tools/%s/aapt.exe" % build_tools_directory,
        "build-tools/%s/aidl.exe" % build_tools_directory,
        "build-tools/%s/zipalign.exe" % build_tools_directory,
        "platform-tools/adb.exe",
    ] + native.glob(
        ["build-tools/%s/aapt2.exe" % build_tools_directory],
        allow_empty = True,
    )

    linux_only_files = [
        "build-tools/%s/aapt" % build_tools_directory,
        "build-tools/%s/aidl" % build_tools_directory,
        "build-tools/%s/zipalign" % build_tools_directory,
        "platform-tools/adb",
    ] + native.glob(
        ["extras", "build-tools/%s/aapt2" % build_tools_directory],
        allow_empty = True,
        exclude_directories = 0,
    )

    # This filegroup is used to pass the minimal contents of the SDK to the
    # Android integration tests. Note that in order to work on Windows, we cannot
    # include directories and must keep the size small.
    native.filegroup(
        name = "files",
        srcs = [
            "build-tools/%s/lib/apksigner.jar" % build_tools_directory,
            "build-tools/%s/lib/d8.jar" % build_tools_directory,
            "build-tools/%s/lib/dx.jar" % build_tools_directory,
            "build-tools/%s/mainDexClasses.rules" % build_tools_directory,
            ":build_tools_libs",
        ] + [
            "platforms/android-%d/%s" % (api_level, filename)
            for api_level in api_levels
            for filename in ["android.jar", "framework.aidl"]
        ] + select({
            ":windows": windows_only_files,
            "//conditions:default": linux_only_files,
        }),
    )

    for api_level in api_levels:
        if api_level >= 23:
            # Android 23 removed most of org.apache.http from android.jar and moved it
            # to a separate jar.
            java_import(
                name = "org_apache_http_legacy-%d" % api_level,
                jars = ["platforms/android-%d/optional/org.apache.http.legacy.jar" % api_level],
            )

        if api_level >= 28:
            # Android 28 removed most of android.test from android.jar and moved it
            # to separate jars.
            java_import(
                name = "legacy_test-%d" % api_level,
                jars = [
                    "platforms/android-%d/optional/android.test.base.jar" % api_level,
                    "platforms/android-%d/optional/android.test.mock.jar" % api_level,
                    "platforms/android-%d/optional/android.test.runner.jar" % api_level,
                ],
                neverlink = 1,
            )

        native.config_setting(
            name = "api_%d_enabled" % api_level,
            flag_values = {
                ":api_level": str(api_level),
            },
        )

        # TODO(katre): Use the Starlark android_sdk
        native.android_sdk(
            name = "sdk-%d" % api_level,
            aapt = select({
                ":windows": "build-tools/%s/aapt.exe" % build_tools_directory,
                "//conditions:default": ":aapt_binary",
            }),
            aapt2 = select({
                ":windows": "build-tools/%s/aapt2.exe" % build_tools_directory,
                "//conditions:default": ":aapt2_binary",
            }),
            adb = select({
                ":windows": "platform-tools/adb.exe",
                "//conditions:default": "platform-tools/adb",
            }),
            aidl = select({
                ":windows": "build-tools/%s/aidl.exe" % build_tools_directory,
                "//conditions:default": ":aidl_binary",
            }),
            android_jar = "platforms/android-%d/android.jar" % api_level,
            apksigner = ":apksigner",
            build_tools_version = build_tools_version,
            dx = select({
                "d8_standalone_dexer": ":d8_compat_dx",
                "dx_standalone_dexer": ":dx_binary",
                "//conditions:default": ":d8_compat_dx",
            }),
            framework_aidl = "platforms/android-%d/framework.aidl" % api_level,
            legacy_main_dex_list_generator = ":generate_main_dex_list",
            main_dex_classes = "build-tools/%s/mainDexClasses.rules" % build_tools_directory,
            proguard = select({
                ":disallow_proguard": ":fail",
                "//conditions:default": "@bazel_tools//tools/jdk:proguard",
            }),
            shrinked_android_jar = "platforms/android-%d/android.jar" % api_level,
            # See https://github.com/bazelbuild/bazel/issues/8757
            tags = ["__ANDROID_RULES_MIGRATION__"],
            zipalign = select({
                ":windows": "build-tools/%s/zipalign.exe" % build_tools_directory,
                "//conditions:default": ":zipalign_binary",
            }),
        )

        native.toolchain(
            name = "sdk-%d-toolchain" % api_level,
            exec_compatible_with = HOST_CONSTRAINTS,
            target_compatible_with = [
                "@platforms//os:android",
            ],
            toolchain = ":sdk-%d" % api_level,
            toolchain_type = "@bazel_tools//tools/android:sdk_toolchain_type",
            target_settings = [
                ":api_%d_enabled" % api_level,
            ],
        )

    native.alias(
        name = "org_apache_http_legacy",
        actual = ":org_apache_http_legacy-%d" % default_api_level,
    )

    sdk_alias_dict = {
        "//conditions:default": "sdk-%d" % default_api_level,
    }

    for api_level in api_levels:
        sdk_alias_dict[":api_%d_enabled" % api_level] = "sdk-%d" % api_level

    native.alias(
        name = "sdk",
        actual = select(
            sdk_alias_dict,
            no_match_error = "Unknown Android SDK level, valid levels are %s" % ",".join([str(level) for level in api_levels]),
        ),
    )

    java_binary(
        name = "apksigner",
        main_class = "com.android.apksigner.ApkSignerTool",
        runtime_deps = ["build-tools/%s/lib/apksigner.jar" % build_tools_directory],
    )

    native.filegroup(
        name = "build_tools_libs",
        srcs = native.glob([
            "build-tools/%s/lib/**" % build_tools_directory,
            # Build tools version 24.0.0 added a lib64 folder.
            "build-tools/%s/lib64/**" % build_tools_directory,
        ], allow_empty = True),
    )

    for tool in ["aapt", "aapt2", "aidl", "zipalign"]:
        native.genrule(
            name = tool + "_runner",
            srcs = [],
            outs = [tool + "_runner.sh"],
            cmd = "\n".join([
                "cat > $@ << 'EOF'",
                "#!/bin/bash",
                "set -eu",
                # The tools under build-tools/VERSION require the libraries under
                # build-tools/VERSION/lib, so we can't simply depend on them as a
                # file like we do with aapt.
                # On Windows however we can use these binaries directly because
                # there's no runfiles support so Bazel just creates a junction to
                # {SDK}/build-tools.
                "SDK=$${0}.runfiles/%s" % name,
                # If $${SDK} is not a directory, it means that this tool is running
                # from a runfiles directory, in the case of
                # android_instrumentation_test. Hence, use the androidsdk
                # that's already present in the runfiles of the current context.
                "if [[ ! -d $${SDK} ]] ; then",
                "  SDK=$$(pwd)/../%s" % name,
                "fi",
                "tool=$${SDK}/build-tools/%s/%s" % (build_tools_directory, tool),
                "exec env LD_LIBRARY_PATH=$${SDK}/build-tools/%s/lib64 $$tool $$*" % build_tools_directory,
                "EOF\n",
            ]),
        )

        native.sh_binary(
            name = tool + "_binary",
            srcs = [tool + "_runner.sh"],
            data = [
                ":build_tools_libs",
                "build-tools/%s/%s" % (build_tools_directory, tool),
            ],
        )

    native.sh_binary(
        name = "fail",
        srcs = select({
            ":windows": [":generate_fail_cmd"],
            "//conditions:default": [":generate_fail_sh"],
        }),
    )

    native.genrule(
        name = "generate_fail_sh",
        outs = ["fail.sh"],
        cmd = "echo -e '#!/bin/bash\\nexit 1' >> $@; chmod +x $@",
        executable = 1,
    )

    native.genrule(
        name = "generate_fail_cmd",
        outs = ["fail.cmd"],
        cmd = "echo @exit /b 1 > $@",
        executable = 1,
    )

    native.genrule(
        name = "main_dex_list_creator_source",
        srcs = [],
        outs = ["main_dex_list_creator.sh"],
        cmd = "\n".join([
            "cat > $@ <<'EOF'",
            "#!/bin/bash",
            "",
            "MAIN_DEX_LIST=$$1",
            "STRIPPED_JAR=$$2",
            "JAR=$$3",
            "" +
            "JAVA_BINARY=$$0.runfiles/%s/main_dex_list_creator_java" % name,
            "$$JAVA_BINARY $$STRIPPED_JAR $$JAR > $$MAIN_DEX_LIST",
            "exit $$?",
            "",
            "EOF\n",
        ]),
    )

    native.sh_binary(
        name = "main_dex_list_creator",
        srcs = ["main_dex_list_creator.sh"],
        data = [":main_dex_list_creator_java"],
    )
    java_binary(
        name = "main_dex_list_creator_java",
        main_class = "com.android.multidex.ClassReferenceListBuilder",
        runtime_deps = [":dx_jar_import"],
    )
    java_binary(
        name = "dx_binary",
        main_class = "com.android.dx.command.Main",
        runtime_deps = [":dx_jar_import"],
    )
    java_import(
        name = "dx_jar_import",
        jars = ["build-tools/%s/lib/dx.jar" % build_tools_directory],
    )
    java_binary(
        name = "generate_main_dex_list",
        jvm_flags = [
            "-XX:+TieredCompilation",
            "-XX:TieredStopAtLevel=1",
            # Consistent with what we use for desugar.
            "-Xms8g",
            "-Xmx8g",
        ],
        main_class = "com.android.tools.r8.GenerateMainDexList",
        runtime_deps = ["@bazel_tools//src/tools/android/java/com/google/devtools/build/android/r8"],
    )
    java_binary(
        name = "d8_compat_dx",
        main_class = "com.google.devtools.build.android.r8.CompatDx",
        runtime_deps = [
            "@bazel_tools//src/tools/android/java/com/google/devtools/build/android/r8",
        ],
    )
    native.alias(
        name = "d8_jar_import",
        actual = "@android_gmaven_r8//jar",
    )

TAGDIR_TO_TAG_MAP = {
    "google_apis_playstore": "playstore",
    "google_apis": "google",
    "default": "android",
    "android-tv": "tv",
    "android-wear": "wear",
}

ARCHDIR_TO_ARCH_MAP = {
    "x86": "x86",
    "armeabi-v7a": "arm",
}

# buildifier: disable=unnamed-macro
def create_system_images_filegroups(system_image_dirs):
    """Generate filegroups for the system images in the Android SDK.

    Args:
      system_image_dirs: list of strings, the directories containing system image
          files to be used to create android_device rules.
    """

    # These images will need to be updated as Android releases new system images.
    # We are intentionally not adding future releases because there is no
    # guarantee that they will work out of the box. Supported system images should
    # be added here once they have been confirmed to work with the Bazel Android
    # testing infrastructure.
    system_images = [
        (tag, str(api), arch)
        for tag in ["android", "google"]
        for api in [10] + list(range(15, 20)) + list(range(21, 30))
        for arch in ("x86", "arm")
    ] + [
        ("playstore", str(api), "x86")
        for api in list(range(24, 30))
    ]
    tv_images = [
        ("tv", str(api), "x86")
        for api in range(21, 30)
    ] + [
        ("tv", "21", "arm"),
        ("tv", "23", "arm"),
    ]
    wear_images = [
        ("wear", str(api), "x86")
        for api in [23, 25, 26, 28]
    ] + [
        ("wear", str(api), "arm")
        for api in [23, 25]
    ]
    supported_system_images = system_images + tv_images + wear_images

    installed_system_images_dirs = {}
    for system_image_dir in system_image_dirs:
        apidir, tagdir, archdir = system_image_dir.split("/")[1:]
        if "-" not in apidir:
            continue
        api = apidir.split("-")[1]  # "android-24" --> "24", "android-O" --> "O"
        if tagdir not in TAGDIR_TO_TAG_MAP:
            continue
        tag = TAGDIR_TO_TAG_MAP[tagdir]
        if archdir not in ARCHDIR_TO_ARCH_MAP:
            continue
        arch = ARCHDIR_TO_ARCH_MAP[archdir]
        if (tag, api, arch) in supported_system_images:
            name = "emulator_images_%s_%s_%s" % (tag, api, arch)
            installed_system_images_dirs[name] = system_image_dir
        else:
            # TODO(bazel-team): If the user has an unsupported system image installed,
            # should we print a warning? This includes all 64-bit system-images.
            pass

    for (tag, api, arch) in supported_system_images:
        name = "emulator_images_%s_%s_%s" % (tag, api, arch)
        if name in installed_system_images_dirs:
            system_image_dir = installed_system_images_dirs[name]

            # For supported system images that exist in /sdk/system-images/, we
            # create a filegroup with their contents.
            native.filegroup(
                name = name,
                srcs = native.glob([
                    "%s/**" % system_image_dir,
                ]),
            )
            native.filegroup(
                name = "%s_qemu2_extra" % name,
                srcs = native.glob(["%s/kernel-ranchu" % system_image_dir], allow_empty = True),
            )
        else:
            # For supported system images that are not installed in the SDK, we
            # create a "poison pill" genrule to display a helpful error message to
            # a user who attempts to run a test against an android_device that
            # they don't have the system image for installed.
            native.genrule(
                name = name,
                outs = [
                    # Necessary so that the build doesn't fail in analysis because
                    # android_device expects a file named source.properties.
                    "poison_pill_for_%s/source.properties" % name,
                ],
                cmd = """echo \
          This rule requires that the Android SDK used by Bazel has the \
          following system image installed: %s. Please install this system \
          image through the Android SDK Manager and try again. ; \
          exit 1
          """ % name,
            )
            native.filegroup(
                name = "%s_qemu2_extra" % name,
                srcs = [],
            )
