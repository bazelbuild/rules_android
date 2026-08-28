# Copyright 2019 The Bazel Authors. All rights reserved.
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
"""Bazel Flags."""

load("@bazel_features//private:util.bzl", "lt")  # buildifier: disable=bzl-visibility
load("//flags:flags_wrapper.bzl", "WrappedFlagsInfo")
load("//rules:utils.bzl", "utils")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

_BoolFlagInfo = provider(
    doc = "Provides information about a boolean flag",
    fields = dict(
        name = "flag name",
        value = "flag value",
        explicit = "whether value was set explicitly",
    ),
)
_BoolFlagGroupInfo = provider(
    doc = "Provides information about a boolean flag group",
    fields = dict(
        name = "group name",
        value = "group value",
        flags = "flag names that belong to this group",
    ),
)
_IntFlagInfo = provider(
    doc = "Provides information about an integer flag",
    fields = dict(
        name = "flag name",
        value = "flag value",
    ),
)
FlagsInfo = provider(
    doc = "Provides all flags",
)

def _get_bool(v):
    v = v.lower()
    if v == "true":
        return True
    if v == "false":
        return False
    fail("Unknown bool: " + v)

def _bool_impl(ctx):
    if ctx.label.name in ctx.var:
        value = _get_bool(ctx.var[ctx.label.name])
        return _BoolFlagInfo(
            name = ctx.label.name,
            value = value,
            explicit = True,
        )
    return _BoolFlagInfo(
        name = ctx.label.name,
        value = ctx.attr.default,
        explicit = False,
    )

bool_flag = rule(
    implementation = _bool_impl,
    attrs = dict(
        default = attr.bool(
            mandatory = True,
        ),
        description = attr.string(
            mandatory = True,
        ),
    ),
    provides = [_BoolFlagInfo],
)

def _bool_group_impl(ctx):
    if ctx.label.name in ctx.var:
        value = _get_bool(ctx.var[ctx.label.name])
        return _BoolFlagGroupInfo(
            name = ctx.label.name,
            value = value,
            flags = [f[_BoolFlagInfo].name for f in ctx.attr.flags],
        )
    return _BoolFlagGroupInfo(
        name = ctx.label.name,
        value = ctx.attr.default,
        flags = [f[_BoolFlagInfo].name for f in ctx.attr.flags],
    )

bool_flag_group = rule(
    implementation = _bool_group_impl,
    attrs = dict(
        default = attr.bool(
            mandatory = True,
        ),
        description = attr.string(
            mandatory = True,
        ),
        flags = attr.label_list(
            mandatory = True,
            providers = [_BoolFlagInfo],
        ),
    ),
    provides = [_BoolFlagGroupInfo],
)

def _int_impl(ctx):
    if ctx.label.name in ctx.var:
        value = int(ctx.var[ctx.label.name])
    else:
        value = ctx.attr.default
    return _IntFlagInfo(
        name = ctx.label.name,
        value = value,
    )

int_flag = rule(
    implementation = _int_impl,
    attrs = dict(
        default = attr.int(
            mandatory = True,
        ),
        description = attr.string(
            mandatory = True,
        ),
    ),
    provides = [_IntFlagInfo],
)

def _flags_impl_internal(bool_flags, bool_flag_groups, int_flags):
    flags = dict()

    # For each group, set all flags to the group value
    for fg in bool_flag_groups:
        for f in fg.flags:
            if f in flags:
                fail("Flag '%s' referenced in multiple flag groups" % f)
            flags[f] = fg.value

    # Set booleans
    for b in bool_flags:
        # Always set explicitly specified flags
        if b.explicit:
            flags[b.name] = b.value
            # If not explicit, only set when not set by a group

        elif b.name not in flags:
            flags[b.name] = b.value

    # Set ints
    for i in int_flags:
        flags[i.name] = i.value

    return FlagsInfo(**flags)

def _flags_impl(ctx):
    return _flags_impl_internal(
        utils.collect_providers(_BoolFlagInfo, ctx.attr.targets),
        utils.collect_providers(_BoolFlagGroupInfo, ctx.attr.targets),
        utils.collect_providers(_IntFlagInfo, ctx.attr.targets),
    )

flags_rule = rule(
    implementation = _flags_impl,
    attrs = dict(
        targets = attr.label_list(),
    ),
)

def _flags_macro():
    flags_rule(
        name = "flags",
        targets = native.existing_rules().keys(),
        visibility = ["//visibility:public"],
    )

def _get_flags(ctx):
    flags = ctx.attr._flags
    if type(flags) != "list":
        return flags[FlagsInfo]
    return flags[0][FlagsInfo]

_POSSIBLY_NATIVE_FLAGS = {
    "desugar_for_android": (lambda ctx: ctx.fragments.android.desugar_java8, "native"),
    "desugar_java8_libs": (lambda ctx: ctx.fragments.android.desugar_java8_libs, "native"),
    "experimental_android_compress_java_resources": (
        lambda ctx: ctx.fragments.android.compress_java_resources,
        "native",
    ),
    "experimental_android_library_exports_manifest_default": (
        lambda ctx: ctx.fragments.android.get_exports_manifest_default,
        "native",
    ),
    "experimental_android_resource_cycle_shrinking": (
        lambda ctx: ctx.fragments.android.use_android_resource_cycle_shrinking,
        "native",
    ),
    "experimental_get_android_java_resources_from_optimized_jar": (
        lambda ctx: ctx.fragments.android.get_java_resources_from_optimized_jar,
        "native",
    ),
    "internal_persistent_android_dex_desugar": (
        lambda ctx: ctx.fragments.android.persistent_android_dex_desugar,
        "native",
    ),
    "internal_persistent_busybox_tools": (
        lambda ctx: ctx.fragments.android.persistent_busybox_tools,
        "native",
    ),
    "internal_persistent_multiplex_android_dex_desugar": (
        lambda ctx: ctx.fragments.android.persistent_multiplex_android_dex_desugar,
        "native",
    ),
    "internal_persistent_multiplex_busybox_tools": (
        lambda ctx: ctx.fragments.android.persistent_multiplex_busybox_tools,
        "native",
    ),
    "experimental_incremental_dexing_after_proguard": (lambda ctx: ctx.fragments.android.incremental_dexing_shards_after_proguard, "native"),
    "dexopts_supported_in_dexsharder": (lambda ctx: ctx.fragments.android.get_dexopts_supported_in_dex_sharder, "native"),
    "fixed_resource_neverlinking": (lambda ctx: ctx.fragments.android.fixed_resource_neverlinking, "native"),
    "android_resource_shrinking": (lambda ctx: ctx.fragments.android.use_android_resource_shrinking, "native"),
    "experimental_android_resource_shrinking": (lambda ctx: ctx.fragments.android.use_android_resource_shrinking, "native"),
    "experimental_android_resource_path_shortening": (lambda ctx: ctx.fragments.android.use_android_resource_path_shortening, "native"),
    "experimental_android_resource_name_obfuscation": (lambda ctx: ctx.fragments.android.use_android_resource_name_obfuscation, "native"),
    "optimizing_dexer": (lambda ctx: ctx.attr._optimizing_dexer, "native"),
}

_LABEL_FLAGS = [
    "optimizing_dexer",
]

def read_possibly_native_flag(ctx, flag_name):
    """
    Canonical API for reading a Android build flag.

    Flags might be defined in Starlark or native-Bazel. This function reads flags
    from the correct source based on supporting Bazel version and --incompatible*
    flags that disable native references.

    Args:
        ctx: Rule's configuration context.
        flag_name: Name of the flag to read, without preceding "--".

    Returns:
        The flag's value.
    """

    # Bazel 9.1+ can disable these fragments with --incompatible_remove_ctx_android_fragment.
    # Disabling them means bazel expects Android to read Starlark flags.
    use_native_def = hasattr(ctx.fragments, "android")

    # Developer override to force the Starlark definition for testing.
    # This would allow us to migrate flags gradually from native to Starlark with flag aliases.
    if _POSSIBLY_NATIVE_FLAGS[flag_name][1] == "starlark":
        use_native_def = False

    if lt("9.1.0"):
        use_native_def = True

    if use_native_def:
        return _POSSIBLY_NATIVE_FLAGS[flag_name][0](ctx)
    else:
        if flag_name in _LABEL_FLAGS:
            val = getattr(ctx.attr, "_starlark_" + flag_name, None)
            if val and not str(val.label).endswith(":empty"):
                return val
            return getattr(ctx.attr, "_" + flag_name, None)

        # First check the new wrapped_flags attribute
        if hasattr(ctx.attr, "_wrapped_flags") and ctx.attr._wrapped_flags:
            wrapped_flags = ctx.attr._wrapped_flags[WrappedFlagsInfo].flags

            if flag_name in wrapped_flags:
                return wrapped_flags[flag_name].value
        elif hasattr(ctx.fragments, "android"):
            return _POSSIBLY_NATIVE_FLAGS[flag_name][0](ctx)

    fail("Unable to read flag value for " + flag_name)

flags = struct(
    DEFINE_bool = bool_flag,
    DEFINE_bool_group = bool_flag_group,
    DEFINE_int = int_flag,
    FLAGS = _flags_macro,
    FlagsInfo = FlagsInfo,
    get = _get_flags,
)

exported_for_test = struct(
    BoolFlagGroupInfo = _BoolFlagGroupInfo,
    BoolFlagInfo = _BoolFlagInfo,
    IntFlagInfo = _IntFlagInfo,
    bool_impl = _bool_impl,
    flags_impl_internal = _flags_impl_internal,
    int_impl = _int_impl,
)
