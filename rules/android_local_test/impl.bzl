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

"""Bazel rule for Android local test."""

load("//rules:acls.bzl", "acls")
load("//rules:attrs.bzl", "attrs")
load("//rules:common.bzl", "common")
load("//rules:java.bzl", "java")
load(
    "//rules:processing_pipeline.bzl",
    "ProviderInfo",
    "processing_pipeline",
)
load("//rules:providers.bzl", "AndroidFilteredJdepsInfo")
load("//rules:resources.bzl", "resources")
load(
    "//rules:utils.bzl",
    "ANDROID_TOOLCHAIN_TYPE",
    "compilation_mode",
    "get_android_sdk",
    "get_android_toolchain",
    "log",
    "utils",
)
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

JACOCOCO_CLASS = "com.google.testing.coverage.JacocoCoverageRunner"
TEST_RUNNER_CLASS = "com.google.testing.junit.runner.BazelTestRunner"

# JVM processes for android_local_test targets are typically short lived. By
# using TieredStopAtLevel=1, aggressive JIT compilations are avoided, which is
# more optimal for android_local_test workloads.
DEFAULT_JIT_FLAGS = ["-XX:+TieredCompilation", "-XX:TieredStopAtLevel=1"]

# Many P99 and above android_local_test targets use a lot of memory so the default 1 GiB
# JVM max heap size is not sufficient. Bump the max heap size to from 1 GiB -> 8 GiB. This performs
# the best across all P% layers from profiling.
DEFAULT_GC_FLAGS = ["-Xmx8g"]

# disable class loading by default for faster classloading and consistent enviroment across
# local and remote execution
DEFAULT_VERIFY_FLAGS = ["-Xverify:none"]

def _validations_processor(ctx, **_unused_sub_ctxs):
    _check_src_pkg(ctx, True)

def _process_manifest(ctx, java_package, **_unused_sub_ctxs):
    manifest_ctx = None
    manifest_values = resources.process_manifest_values(
        ctx,
        ctx.attr.manifest_values,
        acls.get_min_sdk_floor(str(ctx.label)),
    )
    if ctx.file.manifest == None:
        # No manifest provided, generate one
        manifest = ctx.actions.declare_file("_generated/" + ctx.label.name + "/AndroidManifest.xml")
        resources.generate_dummy_manifest(
            ctx,
            out_manifest = manifest,
            java_package = java_package,
            min_sdk_version = int(manifest_values.get("minSdkVersion", 16)),  # minsdk supported by robolectric framework
        )
        manifest_ctx = struct(processed_manifest = manifest, processed_manifest_values = manifest_values)
    else:
        manifest_ctx = resources.bump_min_sdk(
            ctx,
            manifest = ctx.file.manifest,
            manifest_values = ctx.attr.manifest_values,
            floor = acls.get_min_sdk_floor(str(ctx.label)),
            enforce_min_sdk_floor_tool = get_android_toolchain(ctx).enforce_min_sdk_floor_tool.files_to_run,
        )

    return ProviderInfo(
        name = "manifest_ctx",
        value = manifest_ctx,
    )

def _process_resources(ctx, java_package, manifest_ctx, **_unused_sub_ctxs):
    resources_ctx = resources.package(
        ctx,
        deps = ctx.attr.deps,
        manifest = manifest_ctx.processed_manifest,
        manifest_values = manifest_ctx.processed_manifest_values,
        resource_files = ctx.files.resource_files,
        assets = ctx.files.assets,
        assets_dir = ctx.attr.assets_dir,
        resource_configs = ctx.attr.resource_configuration_filters,
        densities = ctx.attr.densities,
        nocompress_extensions = ctx.attr.nocompress_extensions,
        compilation_mode = compilation_mode.get(ctx),
        java_package = java_package,
        shrink_resources = attrs.tristate.no,
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
        android_jar = get_android_sdk(ctx).android_jar,
        busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        host_javabase = ctx.attr._host_javabase,
        # TODO(b/140582167): Throwing on resource conflict need to be rolled
        # out to android_local_test.
        should_throw_on_conflict = False,
    )

    return ProviderInfo(
        name = "resources_ctx",
        value = resources_ctx,
    )

def _process_jvm(ctx, resources_ctx, **_unused_sub_ctxs):
    deps = (
        ctx.attr._implicit_classpath +
        ctx.attr.deps +
        [get_android_toolchain(ctx).testsupport]
    )

    if ctx.configuration.coverage_enabled:
        deps.append(get_android_toolchain(ctx).jacocorunner)
        java_start_class = JACOCOCO_CLASS
        coverage_start_class = TEST_RUNNER_CLASS
    else:
        java_start_class = TEST_RUNNER_CLASS
        coverage_start_class = None

    java_info = java_common.add_constraints(
        java.compile_android(
            ctx,
            ctx.outputs.jar,
            ctx.actions.declare_file(ctx.label.name + "-src.jar"),
            srcs = ctx.files.srcs,
            resources = ctx.files.resources,
            javac_opts = ctx.attr.javacopts,
            r_java = resources_ctx.r_java,
            deps = (
                utils.collect_providers(JavaInfo, deps) +
                [
                    JavaInfo(
                        output_jar = get_android_sdk(ctx).android_jar,
                        compile_jar = get_android_sdk(ctx).android_jar,
                        # The android_jar must not be compiled into the test, it
                        # will bloat the Jar with no benefit.
                        neverlink = True,
                    ),
                ]
            ),
            plugins = utils.collect_providers(JavaPluginInfo, ctx.attr.plugins),
            java_toolchain = common.get_java_toolchain(ctx),
        ),
        constraints = ["android"],
    )

    # TODO(timpeut): some conformance tests require a filtered JavaInfo
    # with no transitive_ deps.
    providers = [java_info]
    runfiles = []

    # Create a filtered jdeps with no resources jar. See b/129011477 for more context.
    if java_info.outputs.jdeps != None:
        filtered_jdeps = ctx.actions.declare_file(ctx.label.name + ".filtered.jdeps")
        filter_jdeps(ctx, java_info.outputs.jdeps, filtered_jdeps, utils.only(resources_ctx.r_java.compile_jars.to_list()))
        providers.append(AndroidFilteredJdepsInfo(jdeps = filtered_jdeps))
        runfiles.append(filtered_jdeps)

    return ProviderInfo(
        name = "jvm_ctx",
        value = struct(
            java_info = java_info,
            providers = providers,
            deps = deps,
            java_start_class = java_start_class,
            coverage_start_class = coverage_start_class,
            android_properties_file = ctx.attr.robolectric_properties_file,
            additional_jvm_flags = [],
        ),
        runfiles = ctx.runfiles(files = runfiles),
    )

def _process_proto(_ctx, **_unused_sub_ctxs):
    return ProviderInfo(
        name = "proto_ctx",
        value = struct(
            proto_extension_registry_dep = depset(),
        ),
    )

def _process_deploy_jar(ctx, java_package, jvm_ctx, proto_ctx, resources_ctx, **_unused_sub_ctxs):
    res_file_path = resources_ctx.validation_result.short_path
    subs = {
        "%android_merged_manifest%": resources_ctx.processed_manifest.short_path,
        "%android_merged_resources%": "jar:file:" + res_file_path + "!/res",
        "%android_merged_assets%": "jar:file:" + res_file_path + "!/assets",
        # The native resources_ctx has the package field, whereas the starlark resources_ctx uses the java_package
        "%android_custom_package%": getattr(resources_ctx, "package", java_package or ""),
        "%android_resource_apk%": resources_ctx.resources_apk.short_path,
    }
    res_runfiles = [
        resources_ctx.resources_apk,
        resources_ctx.validation_result,
        resources_ctx.processed_manifest,
    ]

    properties_file = _genfiles_artifact(ctx, "test_config.properties")
    properties_jar = _genfiles_artifact(ctx, "properties.jar")
    ctx.actions.expand_template(
        template = utils.only(get_android_toolchain(ctx).robolectric_template.files.to_list()),
        output = properties_file,
        substitutions = subs,
    )
    _zip_file(ctx, properties_file, "com/android/tools", properties_jar)
    properties_jar_dep = depset([properties_jar])

    runtime_deps = depset(transitive = [
        x.transitive_runtime_jars
        for x in utils.collect_providers(JavaInfo, ctx.attr.runtime_deps)
    ])
    android_jar_dep = depset([get_android_sdk(ctx).android_jar])
    out_jar_dep = depset([ctx.outputs.jar])
    classpath = depset(
        transitive = [
            proto_ctx.proto_extension_registry_dep,
            out_jar_dep,
            resources_ctx.r_java.compile_jars,
            properties_jar_dep,
            runtime_deps,
            android_jar_dep,
            jvm_ctx.java_info.transitive_runtime_jars,
        ],
    )

    java.singlejar(
        ctx,
        # TODO(timpeut): investigate whether we need to filter the stub classpath as well
        [f for f in classpath.to_list() if f.short_path.endswith(".jar")],
        ctx.outputs.deploy_jar,
        mnemonic = "JavaDeployJar",
        include_build_data = True,
        java_toolchain = common.get_java_toolchain(ctx),
    )
    return ProviderInfo(
        name = "deploy_jar_ctx",
        value = struct(
            classpath = classpath,
        ),
        runfiles = ctx.runfiles(files = res_runfiles, transitive_files = classpath),
    )

def _preprocess_stub(ctx, **_unused_sub_ctxs):
    javabase = ctx.attr._current_java_runtime[java_common.JavaRuntimeInfo]
    java_executable = str(javabase.java_executable_runfiles_path)
    java_executable_files = javabase.files

    # Absolute java_executable does not require any munging
    if java_executable.startswith("/"):
        java_executable = "JAVABIN=" + java_executable

    prefix = ctx.attr._runfiles_root_prefix[BuildSettingInfo].value
    if not java_executable.startswith(prefix):
        java_executable = prefix + java_executable

    java_executable = "JAVABIN=${JAVABIN:-${JAVA_RUNFILES}/" + java_executable + "}"

    substitutes = {
        "%javabin%": java_executable,
        "%load_lib%": "",
        "%set_ASAN_OPTIONS%": "",
    }
    runfiles = [java_executable_files]

    return ProviderInfo(
        name = "stub_preprocess_ctx",
        value = struct(
            substitutes = substitutes,
            runfiles = runfiles,
        ),
    )

def _process_stub(ctx, deploy_jar_ctx, jvm_ctx, stub_preprocess_ctx, **_unused_sub_ctxs):
    runfiles = []

    merged_instr = None
    if ctx.configuration.coverage_enabled:
        merged_instr = ctx.actions.declare_file(ctx.label.name + "_merged_instr.jar")
        java.singlejar(
            ctx,
            [f for f in deploy_jar_ctx.classpath.to_list() if f.short_path.endswith(".jar")],
            merged_instr,
            mnemonic = "JavaDeployJar",
            include_build_data = True,
            java_toolchain = common.get_java_toolchain(ctx),
        )
        runfiles.append(merged_instr)

    stub = ctx.actions.declare_file(ctx.label.name)
    classpath_file = ctx.actions.declare_file(ctx.label.name + "_classpath")
    runfiles.append(classpath_file)
    test_class = _get_test_class(ctx)
    if not test_class:
        # fatal error
        log.error("test_class could not be derived for " + str(ctx.label) +
                  ". Explicitly set test_class or move this source file to " +
                  "a java source root.")

    _create_stub(
        ctx,
        stub_preprocess_ctx.substitutes,
        stub,
        classpath_file,
        deploy_jar_ctx.classpath,
        _get_jvm_flags(ctx, test_class, jvm_ctx.android_properties_file, jvm_ctx.additional_jvm_flags),
        jvm_ctx.java_start_class,
        jvm_ctx.coverage_start_class,
        merged_instr,
    )
    return ProviderInfo(
        name = "stub_ctx",
        value = struct(
            stub = stub,
        ),
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = depset(
                transitive = stub_preprocess_ctx.runfiles,
            ),
        ),
    )

PROCESSORS = dict(
    ValidationsProcessor = _validations_processor,
    ManifestProcessor = _process_manifest,
    ResourceProcessor = _process_resources,
    JvmProcessor = _process_jvm,
    ProtoProcessor = _process_proto,
    DeployJarProcessor = _process_deploy_jar,
    StubPreProcessor = _preprocess_stub,
    StubProcessor = _process_stub,
)

def finalize(
        ctx,
        jvm_ctx,
        proto_ctx,
        providers,
        runfiles,
        stub_ctx,
        validation_outputs,
        **_unused_sub_ctxs):
    """Creates the final providers for the rule.

    Args:
      ctx: The context.
      jvm_ctx: ProviderInfo. The jvm ctx.
      proto_ctx: ProviderInfo. The proto ctx.
      providers: sequence of providers. The providers to propagate.
      runfiles: Runfiles. The runfiles collected during processing.
      stub_ctx: ProviderInfo. The stub ctx.
      validation_outputs: sequence of Files. The validation outputs.
      **_unused_sub_ctxs: Unused ProviderInfo.

    Returns:
      A struct with Android and Java legacy providers and a list of providers.
    """
    runfiles = runfiles.merge(ctx.runfiles(collect_data = True))
    runfiles = runfiles.merge(utils.get_runfiles(ctx, jvm_ctx.deps + ctx.attr.data + ctx.attr.runtime_deps))

    providers.extend([
        DefaultInfo(
            files = depset(
                [ctx.outputs.jar, stub_ctx.stub],
                transitive = [proto_ctx.proto_extension_registry_dep],
                order = "preorder",
            ),
            executable = stub_ctx.stub,
            runfiles = runfiles,
        ),
        OutputGroupInfo(
            _validation = depset(validation_outputs),
        ),
        coverage_common.instrumented_files_info(
            ctx = ctx,
            source_attributes = ["srcs"],
            dependency_attributes = ["deps", "runtime_deps", "data"],
        ),
    ])
    return providers

_PROCESSING_PIPELINE = processing_pipeline.make_processing_pipeline(
    processors = PROCESSORS,
    finalize = finalize,
)

def impl(ctx):
    java_package = java.resolve_package_from_label(ctx.label, ctx.attr.custom_package)
    return processing_pipeline.run(ctx, java_package, _PROCESSING_PIPELINE)

def _check_src_pkg(ctx, warn = True):
    pkg = ctx.label.package
    for attr in ctx.attr.srcs:
        if attr.label.package != pkg:
            msg = "Do not import %s directly. Either move the file to this package or depend on an appropriate rule there." % attr.label
            if warn:
                log.warn(msg)
            else:
                log.error(msg)

def _genfiles_artifact(ctx, name):
    return ctx.actions.declare_file(
        "/".join([ctx.genfiles_dir.path, ctx.label.name, name]),
    )

def _get_test_class(ctx):
    # Use the specified test_class if set
    if ctx.attr.test_class != "":
        return ctx.attr.test_class

    # Use a heuristic based on the rule name and the "srcs" list
    # to determine the primary Java class.
    expected = "/" + ctx.label.name + ".java"
    for f in ctx.attr.srcs:
        path = f.label.package + "/" + f.label.name
        if path.endswith(expected):
            return java.resolve_package(path[:-5])

    # Last resort: Use the name and package name of the target.
    return java.resolve_package(ctx.label.package + "/" + ctx.label.name)

def _create_stub(
        ctx,
        substitutes,
        stub_file,
        classpath_file,
        runfiles,
        jvm_flags,
        java_start_class,
        coverage_start_class,
        merged_instr):
    subs = {
        "%needs_runfiles%": "1",
        "%runfiles_manifest_only%": "",
        # To avoid cracking open the depset, classpath is read from a separate
        # file created in its own action. Needed as expand_template does not
        # support ctx.actions.args().
        "%classpath%": "$(eval echo $(<%s))" % (classpath_file.short_path),
        "%java_start_class%": java_start_class,
        "%jvm_flags%": " ".join(jvm_flags),
        "%workspace_prefix%": ctx.workspace_name + "/",
    }

    if coverage_start_class:
        prefix = ctx.attr._runfiles_root_prefix[BuildSettingInfo].value
        subs["%set_jacoco_metadata%"] = (
            "export JACOCO_METADATA_JAR=${JAVA_RUNFILES}/" + prefix +
            merged_instr.short_path
        )
        subs["%set_jacoco_main_class%"] = (
            "export JACOCO_MAIN_CLASS=" + coverage_start_class
        )
        subs["%set_jacoco_java_runfiles_root%"] = (
            "export JACOCO_JAVA_RUNFILES_ROOT=${JAVA_RUNFILES}/" + prefix
        )
    else:
        subs["%set_jacoco_metadata%"] = ""
        subs["%set_jacoco_main_class%"] = ""
        subs["%set_jacoco_java_runfiles_root%"] = ""

    subs.update(substitutes)

    ctx.actions.expand_template(
        template = utils.only(get_android_toolchain(ctx).java_stub.files.to_list()),
        output = stub_file,
        substitutions = subs,
        is_executable = True,
    )

    args = ctx.actions.args()
    args.add_joined(
        runfiles,
        join_with = ":",
        map_each = _get_classpath,
    )
    args.set_param_file_format("multiline")
    ctx.actions.write(
        output = classpath_file,
        content = args,
    )
    return stub_file

def _get_classpath(s):
    return "${J3}" + s.short_path

def _get_jvm_flags(ctx, main_class, robolectric_properties_path, additional_jvm_flags):
    return [
        "-ea",
        "-Dbazel.test_suite=" + main_class,
        "-Drobolectric.offline=true",
        "-Drobolectric-deps.properties=" + robolectric_properties_path,
        "-Duse_framework_manifest_parser=true",
        "-Drobolectric.logging=stdout",
        "-Drobolectric.logging.enabled=true",
        "-Dorg.robolectric.packagesToNotAcquire=com.google.testing.junit.runner.util",
    ] + DEFAULT_JIT_FLAGS + DEFAULT_GC_FLAGS + DEFAULT_VERIFY_FLAGS + additional_jvm_flags + [
        ctx.expand_make_variables(
            "jvm_flags",
            ctx.expand_location(flag, ctx.attr.data),
            {},
        )
        for flag in ctx.attr.jvm_flags
    ]

def _zip_file(ctx, f, dir_name, out_zip):
    cmd = """
base=$(pwd)
tmp_dir=$(mktemp -d)

cd $tmp_dir
mkdir -p {dir_name}
cp $base/{f} {dir_name}
$base/{zip_tool} -jt -X -q $base/{out_zip} {dir_name}/$(basename {f})
""".format(
        zip_tool = get_android_toolchain(ctx).zip_tool.files_to_run.executable.path,
        f = f.path,
        dir_name = dir_name,
        out_zip = out_zip.path,
    )
    ctx.actions.run_shell(
        command = cmd,
        inputs = [f],
        tools = get_android_toolchain(ctx).zip_tool.files,
        outputs = [out_zip],
        mnemonic = "AddToZip",
        toolchain = ANDROID_TOOLCHAIN_TYPE,
    )

def filter_jdeps(ctx, in_jdeps, out_jdeps, filter_suffix):
    """Runs the JdepsFilter tool.

    Args:
      ctx: The context.
      in_jdeps: File. The input jdeps file.
      out_jdeps: File. The filtered jdeps output.
      filter_suffix: File. The jdeps suffix to filter.
    """
    args = ctx.actions.args()
    args.add("--in")
    args.add(in_jdeps.path)
    args.add("--target")
    args.add(filter_suffix)
    args.add("--out")
    args.add(out_jdeps.path)
    ctx.actions.run(
        inputs = [in_jdeps],
        outputs = [out_jdeps],
        executable = get_android_toolchain(ctx).jdeps_tool.files_to_run,
        arguments = [args],
        mnemonic = "JdepsFilter",
        progress_message = "Filtering jdeps",
        toolchain = ANDROID_TOOLCHAIN_TYPE,
    )
