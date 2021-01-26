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

load("@rules_android//rules:utils.bzl", "utils")

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
_NativeBoolFlagInfo = provider(
    doc = "Provides information about a native boolean flag",
    fields = dict(
        name = "flag name, the name of the native flag being accessed.",
        value = "flag value, derived from config_setting targets that access the value",
    ),
)
FlagsInfo = provider(
    doc = "Provides all flags",
)

def _native_bool_impl(ctx):
    return _NativeBoolFlagInfo(
        name = ctx.label.name,
        value = ctx.attr.value,
    )

native_bool_flag = rule(
    implementation = _native_bool_impl,
    attrs = dict(
        value = attr.bool(mandatory = True),
    ),
    provides = [_NativeBoolFlagInfo],
)

def native_bool_flag_macro(name, description):
    """Provides access to a native boolean flag from Starlark.

    Args:
      name: The name of the native flag to access.
      description: The description of the flag.
    """
    native.config_setting(
        name = name + "_on",
        values = {name: "True"},
    )
    native.config_setting(
        name = name + "_off",
        values = {name: "False"},
    )
    native_bool_flag(
        name = name,
        value = select({
            (":" + name + "_on"): True,
            (":" + name + "_off"): False,
        }),
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

def _flags_impl_internal(bool_flags, bool_flag_groups, int_flags, native_bool_flags):
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

    # Set native bool flags
    for n in native_bool_flags:
        if n.name in flags:
            fail("Flag '%s' defined as both native and non-native flag type" % n.name)
        flags[n.name] = n.value

    return FlagsInfo(**flags)

def _flags_impl(ctx):
    return _flags_impl_internal(
        utils.collect_providers(_BoolFlagInfo, ctx.attr.targets),
        utils.collect_providers(_BoolFlagGroupInfo, ctx.attr.targets),
        utils.collect_providers(_IntFlagInfo, ctx.attr.targets),
        utils.collect_providers(_NativeBoolFlagInfo, ctx.attr.targets),
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
    return ctx.attr._flags[FlagsInfo]

flags = struct(
    DEFINE_bool = bool_flag,
    DEFINE_bool_group = bool_flag_group,
    DEFINE_int = int_flag,
    EXPOSE_native_bool = native_bool_flag_macro,
    FLAGS = _flags_macro,
    FlagsInfo = FlagsInfo,
    get = _get_flags,
)

exported_for_test = struct(
    BoolFlagGroupInfo = _BoolFlagGroupInfo,
    BoolFlagInfo = _BoolFlagInfo,
    IntFlagInfo = _IntFlagInfo,
    NativeBoolFlagInfo = _NativeBoolFlagInfo,
    bool_impl = _bool_impl,
    flags_impl_internal = _flags_impl_internal,
    int_impl = _int_impl,
    native_bool_flag_macro = native_bool_flag_macro,
)
