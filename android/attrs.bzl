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

load(":providers.bzl", "AndroidAppsInfo", "AndroidDeviceScriptFixtureInfo", "AndroidHostServiceFixtureInfo", "StarlarkApkInfo")
load(":utils.bzl", "log")


def _add(attrs, *others):
    new = {}
    new.update(attrs)
    for o in others:
        for name in o.keys():
            if name in new:
                log.error("Attr '%s' is defined twice." % name)
            new[name] = o[name]
    return new

def _make_tristate_attr(default, doc = "", mandatory = False):
    return attr.int(
        default = default,
        doc = doc,
        mandatory = mandatory,
        values = [-1, 0, 1],
    )

_tristate = struct(
    create = _make_tristate_attr,
    yes = 1,
    no = 0,
    auto = -1,
)

attrs = struct(
    tristate = _tristate,
    add = _add,
)

APK_IMPORT_ATTRS = dict(
    unsigned_apk = attr.label(
        allow_single_file = [".apk"],
        doc = "Unsigned APK.",
        mandatory = True,
    ),
)

ANDROID_INSTRUMENTATION_TEST_ATTRS = dict(
    data = attr.label_list(
        allow_files = True,
    ),
    fixtures = attr.label_list(
        allow_files = False,
        doc = (
            "Test fixtures. Currently supports a single host fixture and multiple " +
            "device fixtures, which will be executed in the order they are specified."
        ),
        providers = [
            [AndroidAppsInfo],
            [AndroidDeviceScriptFixtureInfo],
            [AndroidHostServiceFixtureInfo],
        ],
    ),
    parallel_dex2oat = _tristate.create(
        default = _tristate.auto,
    ),
    support_apps = attr.label_list(
        providers = [[ApkInfo], [StarlarkApkInfo]],
        cfg = "target",
        doc = "Other APKs to install on the device before the instrumentation test starts.",
    ),
    target_device = attr.label(
        allow_files = False,
        allow_rules = ["android_device"],
        # TODO(b/133183604): Set this correctly. The native implementation uses host configuration,
        # which is correct as the device is run on the host, but this causes preinstalled apps
        # to be built in host configuration which is wrong. For now we set this to target,
        # but ideally android_device will have a host -> target transition so both the device
        # and the preinstalled apps can be built correctly.
        cfg = "target",
        doc = "The `android_device` target the test should run on.",
        executable = True,
        mandatory = True,
    ),
    test_app = attr.label(
        allow_files = False,
        doc = "The `android_binary` target containing the test classes. " +
              "The `android_binary` target must specify which target it is testing " +
              "through its `instruments` attribute.",
        mandatory = True,
    ),
    # TODO(str): Remove when fully migrated to android_instrumentation_test
    _android_test_migration_deps = attr.label_list(
        allow_files = True,
    ),
    # TODO(str): Remove when fully migrated to android_instrumentation_test
    _android_test_migration = attr.bool(
        default = False,
    ),
    _test_entry_point = attr.label(
        cfg = "host",
        default = "@android_test_support//:instrumentation_test_runner",
        executable = True,
    ),
    _test_stub_script = attr.label(
        cfg = "host",
        default = ":android_instrumentation_test_stub_script.sh",
        allow_single_file = True,
    ),
)

