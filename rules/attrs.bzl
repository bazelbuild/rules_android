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
"""Common attributes for Android rules."""

load("//providers:providers.bzl", "ApkInfo")
load("//rules:android_split_transition.bzl", "android_transition")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_java//java/common:java_plugin_info.bzl", "JavaPluginInfo")
load(":utils.bzl", "ANDROID_SDK_TOOLCHAIN_TYPE", "log")

visibility(PROJECT_VISIBILITY)

def _add(attrs, *others):
    new = {}
    new.update(attrs)
    for o in others:
        for name in o.keys():
            if name in new:
                log.error("Attr '%s' is defined twice." % name)
            new[name] = o[name]
    return new

def _replace(attrs, **kwargs):
    # Verify that new values are replacing existing ones, not adding.
    for name in kwargs.keys():
        if name not in attrs:
            log.error("Attr '%s' is not defined, replacement failed." % name)
    new = dict()
    new.update(attrs)
    new.update(kwargs)
    return new

def _make_tristate_attr(default, doc = "", mandatory = False):
    return attr.int(
        default = default,
        doc = doc,
        mandatory = mandatory,
        values = [-1, 0, 1],
    )

def _normalize_tristate(attr_value):
    """Normalizes the tristate value going into a rule.

    This is required because "tristate" is not officially supported as an
    attribute type. An equivalent attribute type is an in with a constrained
    set of values, namely [-1, 0, 1]. Unfortunately, tristate accepts
    multiple types, integers, booleans and strings ("auto"). As a result, this
    method normalizes the inputs to an integer.

    This method needs to be applied to attributes that were formally tristate
    to normalize the inputs.
    """
    if type(attr_value) == "int":
        return attr_value

    if type(attr_value) == "string":
        if attr_value.lower() == "auto":
            return -1

    if type(attr_value) == "bool":
        return int(attr_value)

    return attr_value  # Return unknown type, let the rule fail.

_tristate = struct(
    create = _make_tristate_attr,
    normalize = _normalize_tristate,
    yes = 1,
    no = 0,
    auto = -1,
)

_JAVA_RUNTIME = dict(
    _host_javabase = attr.label(
        cfg = "exec",
        default = Label("//tools/jdk:current_java_runtime"),
    ),
)

# Android SDK attribute.
_ANDROID_SDK = dict(
    _dummy_android_sdk = attr.label(
        default = "//toolchains/android_sdk:dummy_sdk_tools",
    ),
)


# Compilation attributes for Android rules.
def _compilation_attributes(apply_android_transition = False):
    return _add(
        dict(
            assets = attr.label_list(
                allow_files = True,
                cfg = "target",
                doc = ("The list of assets to be packaged. This is typically a glob of " +
                       "all files under the assets directory. You can also reference " +
                       "other rules (any rule that produces files) or exported files in " +
                       "the other packages, as long as all those files are under the " +
                       "assets_dir directory in the corresponding package."),
            ),
            assets_dir = attr.string(
                doc = ("The string giving the path to the files in assets. " +
                       "The pair assets and assets_dir describe packaged assets and either both " +
                       "attributes should be provided or none of them."),
            ),
            custom_package = attr.string(
                doc = ("Java package for which java sources will be generated. " +
                       "By default the package is inferred from the directory where the BUILD file " +
                       "containing the rule is. You can specify a different package but this is " +
                       "highly discouraged since it can introduce classpath conflicts with other " +
                       "libraries that will only be detected at runtime."),
            ),
            manifest = attr.label(
                allow_single_file = [".xml"],
                cfg = android_transition if apply_android_transition else "target",
                doc = ("The name of the Android manifest file, normally " +
                       "AndroidManifest.xml. Must be defined if resource_files or assets are defined."),
            ),
            resource_files = attr.label_list(
                allow_files = True,
                cfg = android_transition if apply_android_transition else "target",
                doc = ("The list of resources to be packaged. This " +
                       "is typically a glob of all files under the res directory. Generated files " +
                       "(from genrules) can be referenced by Label here as well. The only " +
                       "restriction is that the generated outputs must be under the same \"res\" " +
                       "directory as any other resource files that are included."),
            ),
            data = attr.label_list(
                allow_files = True,
                cfg = android_transition if apply_android_transition else "target",
                doc = (
                    "Files needed by this rule at runtime. May list file or rule targets. Generally allows any target.\n\n" +
                    "The default outputs and runfiles of targets in the `data` attribute should appear in the `*.runfiles` area of" +
                    "any executable which is output by or has a runtime dependency on this target. " +
                    "This may include data files or binaries used when this target's " +
                    "[srcs](https://docs.bazel.build/versions/main/be/common-definitions.html#typical.srcs) are executed. " +
                    "See the [data dependencies](https://docs.bazel.build/versions/main/build-ref.html#data) section " +
                    "for more information about how to depend on and use data files.\n\n" +
                    "New rules should define a `data` attribute if they process inputs which might use other inputs at runtime. " +
                    "Rules' implementation functions must also " +
                    "[populate the target's runfiles](https://docs.bazel.build/versions/main/skylark/rules.html#runfiles) " +
                    "from the outputs and runfiles of any `data` attribute, as well as runfiles from any dependency attribute " +
                    "which provides either source code or runtime dependencies."
                ),
            ),
            plugins = attr.label_list(
                providers = [JavaPluginInfo],
                cfg = "exec",
                doc = (
                    "Java compiler plugins to run at compile-time. " +
                    "Every `java_plugin` specified in the plugins attribute will be run whenever this rule is built. " +
                    "A library may also inherit plugins from dependencies that use [exported_plugins](https://docs.bazel.build/versions/main/be/java.html#java_library.exported_plugins). " +
                    "Resources generated by the plugin will be included in the resulting jar of this rule."
                ),
            ),
            javacopts = attr.string_list(
                doc = (
                    "Extra compiler options for this library. " +
                    "Subject to \"[Make variable](https://docs.bazel.build/versions/main/be/make-variables.html)\" substitution and " +
                    "[Bourne shell tokenization](https://docs.bazel.build/versions/main/be/common-definitions.html#sh-tokenization).\n" +
                    "These compiler options are passed to javac after the global compiler options."
                ),
            ),
            # TODO: Expose getPlugins() in JavaConfiguration.java
            #       com/google/devtools/build/lib/rules/java/JavaConfiguration.java
            #       com/google/devtools/build/lib/rules/java/JavaOptions.java
            #
            # _java_plugins = attr.label(
            #     allow_rules = ["java_plugin"],
            #     default = configuration_field(
            #         fragment = "java",
            #         name = "plugin",
            #     ),
            # ),
        ),
        _JAVA_RUNTIME,
    )

# Attributes for rules that use the AndroidDataContext android_data.make_context
_DATA_CONTEXT = _add(
    dict(
        # Additional attrs needed for AndroidDataContext
        _add_g3itr_xslt = attr.label(
            cfg = "exec",
            default = Label("//tools/android/xslt:add_g3itr.xslt"),
            allow_single_file = True,
        ),
        _android_manifest_merge_tool = attr.label(
            cfg = "exec",
            default = Label("//tools/android:merge_manifests"),
            executable = True,
        ),
        _xsltproc_tool = attr.label(
            cfg = "exec",
            default = Label("//tools/android/xslt:xslt"),
            allow_files = True,
        ),
    ),
    _ANDROID_SDK,
)






ANDROID_SDK_ATTRS = dict(
    aapt = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
        mandatory = True,
    ),
    aapt2 = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    aidl = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
        mandatory = True,
    ),
    aidl_lib = attr.label(
        allow_files = [".jar"],
        doc = "Deprecated, only used for the soon to be deleted forked compiler.",
    ),
    android_jar = attr.label(
        allow_single_file = [".jar"],
        cfg = "exec",
        mandatory = True,
    ),
    annotations_jar = attr.label(
        allow_single_file = [".jar"],
        cfg = "exec",
    ),
    apkbuilder = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    apksigner = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
        mandatory = True,
    ),
    adb = attr.label(
        allow_single_file = True,
        cfg = "exec",
        executable = True,
        mandatory = True,
    ),
    build_tools_version = attr.string(),
    dexdump = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
        mandatory = False,
    ),
    dx = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
        mandatory = True,
    ),
    framework_aidl = attr.label(
        allow_single_file = True,
        cfg = "exec",
        mandatory = True,
    ),
    legacy_main_dex_list_generator = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    main_dex_classes = attr.label(
        allow_single_file = True,
        cfg = "exec",
        mandatory = True,
    ),
    main_dex_list_creator = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
        mandatory = True,
    ),
    proguard = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
        mandatory = True,
    ),
    source_properties = attr.label(
        allow_single_file = True,
        cfg = "exec",
    ),
    zipalign = attr.label(
        allow_files = True,
        cfg = "exec",
        executable = True,
        mandatory = True,
    ),
    _proguard = attr.label(
        cfg = "exec",
        default = configuration_field(
            fragment = "java",
            name = "proguard_top",
        ),
    ),
)

# Attributes for resolving platform-based toolchains. Only needed by the native
# DexArchiveAspect.
_ANDROID_TOOLCHAIN_ATTRS = dict(
    _android_sdk_toolchain_type = attr.label(
        allow_rules = ["toolchain_type"],
        default = ANDROID_SDK_TOOLCHAIN_TYPE,
    ),
)

ANDROID_TOOLS_DEFAULTS_JAR_ATTRS = _add(_ANDROID_SDK)

_AUTOMATIC_EXEC_GROUPS_ENABLED = dict(
    _use_auto_exec_groups = attr.bool(default = True),
)

attrs = struct(
    ANDROID_SDK = _ANDROID_SDK,
    compilation_attributes = _compilation_attributes,
    DATA_CONTEXT = _DATA_CONTEXT,
    JAVA_RUNTIME = _JAVA_RUNTIME,
    ANDROID_TOOLCHAIN_ATTRS = _ANDROID_TOOLCHAIN_ATTRS,
    tristate = _tristate,
    add = _add,
    replace = _replace,
    AUTOMATIC_EXEC_GROUPS_ENABLED = _AUTOMATIC_EXEC_GROUPS_ENABLED,
)
