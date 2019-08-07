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

"""Rule implementation for android_instrumentation_test.

https://docs.bazel.build/versions/master/be/android.html#android_instrumentation_test

An `android_instrumentation_test` rule runs Android instrumentation tests. It
will start an emulator, install the application being tested, the test
application, and any other needed applications, and run the tests defined in
the test package.

The `test_app` attribute specifies the `android_binary` which contains the
test. This `android_binary` in turn specifies the `android_binary` application
under test through its `instruments` attribute.

Example:

  # In java/com/samples/hello_world/BUILD
  android_library(
      name = "hello_world_lib",
      srcs = ["Lib.java"],
      manifest = "LibraryManifest.xml",
      resource_files = glob(["res/**"]),
  )
  # The app under test
  android_binary(
      name = "hello_world_app",
      manifest = "AndroidManifest.xml",
      deps = [":hello_world_lib"],
  )

  # In javatests/com/samples/hello_world/BUILD
  android_library(
      name = "hello_world_test_lib",
      srcs = ["Tests.java"],
      deps = [
        "//java/com/samples/hello_world:hello_world_lib",
        ...  # test dependencies such as Espresso and Mockito
      ],
  )

  # The test app
  android_binary(
      name = "hello_world_test_app",
      instruments = "//java/com/samples/hello_world:hello_world_app",
      manifest = "AndroidManifest.xml",
      deps = ["hello_world_test_lib"],
  )

  android_instrumentation_test(
      name = "hello_world_uiinstrumentation_tests",
      target_device = ":some_target_device",
      test_app = ":hello_world_test_app",
  )
"""

load(":attrs.bzl", "ANDROID_INSTRUMENTATION_TEST_ATTRS", "attrs")
load(
    ":providers.bzl",
    "AndroidAppsInfo",
    "AndroidDeviceScriptFixtureInfo",
    "AndroidHostServiceFixtureInfo",
    "StarlarkApkInfo",
)
load(
    ":android_instrumentation_test_addons.bzl",
    "ADDON_ATTRS",
    "get_addon_substitutions",
    "get_addon_targets",
    "get_test_runner",
    "optimize_apks",
    "should_optimize_apks",
)
load(":utils.bzl", "log", "utils")

def _dedup(data):
    seen = {}
    return [seen.setdefault(x, x) for x in data if x not in seen]

def _impl(ctx):
    # Main entry point into the Android test runner.
    test_runner = get_test_runner(ctx)

    runfiles = utils.get_runfiles(ctx, [
        test_runner.test_entry_point.target,
        ctx.attr.target_device,
    ] + get_addon_targets(ctx))

    # TODO(str): remove after android_test migration
    if ctx.attr._android_test_migration:
        # Test APK is a predeclared output on android_test
        ctx.actions.run_shell(
            inputs = [ctx.attr.test_app[ApkInfo].signed_apk],
            outputs = [ctx.outputs.test_app],
            command = "cp %s %s" % (ctx.attr.test_app[ApkInfo].signed_apk.path, ctx.outputs.test_app.path),
        )
        runfiles = runfiles.merge(ctx.runfiles(files = [ctx.outputs.test_app]))

    apks_to_install = []

    if AndroidInstrumentationInfo in ctx.attr.test_app:
        apks_to_install.extend(optimize_apks(ctx, [ctx.attr.test_app[AndroidInstrumentationInfo].target]))
    if ApkInfo in ctx.attr.test_app:
        apks_to_install.extend(optimize_apks(ctx, [ctx.attr.test_app[ApkInfo]]))
    elif StarlarkApkInfo in ctx.attr.test_app:
        # Do not dex2oat a prebuilt apk, as we do not have the signing keys
        apks_to_install.append(ctx.attr.test_app[StarlarkApkInfo].unsigned_apk)
    apks_to_install.extend(
        optimize_apks(ctx, utils.collect_providers(ApkInfo, ctx.attr._android_test_migration_deps, ctx.attr.support_apps)),
    )

    # Do not dex2oat prebuilt support apps.
    apks_to_install.extend(
        [info.unsigned_apk for info in utils.collect_providers(StarlarkApkInfo, ctx.attr.support_apps)],
    )

    # TODO(str): Fail if APK is on data attribute, use support_apps instead.
    apks_to_install.extend([info.signed_apk for info in utils.collect_providers(ApkInfo, ctx.attr.data)])

    # TODO(str): Turn this on after all tests are migrated to android_instrumentation_test.
    # # Fail if APK is on data attribute, use support_apps instead.
    # for data_dep in ctx.attr.data:
    #     if ApkInfo in data_dep:
    #         log.error(("The target %s in the 'data' attributes provides an APK. This is not " +
    #             "supported, please use 'support_apps' instead.") % data_dep.label)

    # Data runfiles from local data attribute are pushed to the device, collect all data runfiles
    device_data_runfiles = ctx.runfiles(collect_data = True)

    # Maintain ordering of fixture scripts, as they must be executed in the same order
    # that they are passed on the rule attrs.
    fixture_scripts = []
    host_service_fixtures = []
    for attr in ctx.attr.fixtures:
        if AndroidDeviceScriptFixtureInfo in attr:
            fixture_scripts.extend(attr[AndroidDeviceScriptFixtureInfo].fixture_script_path.split(","))

            # Device script fixture runfiles need to get pushed to the device, add to data_runfiles.
            device_data_runfiles = device_data_runfiles.merge(attr[AndroidDeviceScriptFixtureInfo].runfiles)
        if AndroidHostServiceFixtureInfo in attr:
            host_service_fixtures.append(attr[AndroidHostServiceFixtureInfo])
            runfiles = runfiles.merge(attr[AndroidHostServiceFixtureInfo].runfiles)
        if AndroidAppsInfo in attr:
            apks_to_install.extend(optimize_apks(ctx, attr[AndroidAppsInfo].apps))

    data_deps = [d.short_path for d in device_data_runfiles.files.to_list()]

    # Add device data runfiles to runfiles, otherwise they wouldn't get built.
    runfiles = runfiles.merge(device_data_runfiles)

    # TODO(str): Add support for more than one android_host_service_fixture
    if len(host_service_fixtures) > 1:
        log.error("android_instrumentation_test accepts at most one android_host_service_fixture")

    apks_to_install = _dedup(apks_to_install)

    workspace = "${TEST_SRCDIR}/%s" % ctx.workspace_name

    substitutions = {
        "%apks_to_install%": ",".join(
            ["%s/%s" % (workspace, apk.short_path) for apk in apks_to_install],
        ),
        "%data_deps%": ",".join(["%s/%s" % (workspace, data) for data in data_deps]),
        "%device_broker_type%": "WRAPPED_EMULATOR",  # TODO: remove hardcode
        "%device_script%": "%s/%s" % (workspace, ctx.executable.target_device.short_path),
        "%dex2oat_on_cloud_enabled%": str(should_optimize_apks(ctx)),
        "%fixture_scripts%": ",".join(fixture_scripts),
        "%test_entry_point%": test_runner.test_entry_point.executable.short_path,
        "%test_label%": str(ctx.label),
        "%test_suite_property_name%": test_runner.test_suite_property_name,
    }
    substitutions.update(get_addon_substitutions(ctx))

    # TODO(str): Refactor once we support more than one android_host_service_fixture
    if len(host_service_fixtures) == 0:
        substitutions["%host_service_fixtures%"] = ""
        substitutions["%host_service_fixture_services%"] = ""
        substitutions["%proxy%"] = ""
    else:
        substitutions["%host_service_fixtures%"] = "%s/%s" % (
            workspace,
            host_service_fixtures[0].executable_path,
        )
        substitutions["%host_service_fixture_services%"] = ",".join(
            host_service_fixtures[0].service_names,
        )
        substitutions["%proxy%"] = host_service_fixtures[0].proxy_name

    coverage_files = depset()
    substitutions["%jacoco_metadata%"] = ""
    if ctx.configuration.coverage_enabled:
        if AndroidInstrumentationInfo not in ctx.attr.test_app:
            log.warn("Coverage requested but unable to identify app under test. Coverage will not be run.")
        else:
            classpath = ctx.actions.declare_file(ctx.label.name + "_coverage_runtime_classpath.txt")
            coverage_metadata = ctx.attr.test_app[AndroidInstrumentationInfo].target.coverage_metadata
            ctx.actions.write(classpath, "%s\n" % coverage_metadata.short_path)
            substitutions["%jacoco_metadata%"] = classpath.short_path
            coverage_files = depset(items = [classpath, coverage_metadata])

    ctx.actions.expand_template(
        template = ctx.file._test_stub_script,
        output = ctx.outputs.runner,
        substitutions = substitutions,
    )

    runfiles = runfiles.merge(ctx.runfiles(apks_to_install, transitive_files = coverage_files))

    return [
        DefaultInfo(
            executable = ctx.outputs.runner,
            runfiles = runfiles,
        ),
        testing.ExecutionInfo({"requires-kvm": "1", "requires-net:external": "1"}),
        coverage_common.instrumented_files_info(
            ctx,
            dependency_attributes = ["test_app"],
        ),
    ]

def _outputs(_android_test_migration):
    outputs = dict(runner = "%{name}_runner.sh")
    if _android_test_migration:
        outputs["test_app"] = "%{name}.apk"
    return outputs

android_instrumentation_test = rule(
    attrs = attrs.add(ANDROID_INSTRUMENTATION_TEST_ATTRS, ADDON_ATTRS),
    fragments = ["android"],
    implementation = _impl,
    outputs = _outputs,
    test = True,
)
