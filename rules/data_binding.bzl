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

"""Bazel Android Data Binding."""

load(":utils.bzl", _utils = "utils")

# Data Binding context attributes.
_JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_INPUTS = \
    "java_annotation_processor_additional_inputs"
_JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_OUTPUTS = \
    "java_annotation_processor_additional_outputs"
_JAVA_PLUGINS = "java_plugins"
_JAVA_SRCS = "java_srcs"
_JAVAC_OPTS = "javac_opts"
_PROVIDERS = "providers"

DataBindingContextInfo = provider(
    doc = "Contains data from processing Android Data Binding.",
    fields = {
        _JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_INPUTS: (
            "Additional inputs required by the Java annotation processor."
        ),
        _JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_OUTPUTS: (
            "Additional outputs produced by the Java annotation processor."
        ),
        _JAVA_PLUGINS: "Data Binding Java annotation processor",
        _JAVA_SRCS: "Java sources required by the Java annotation processor.",
        _JAVAC_OPTS: (
            "Additional Javac opts required by the Java annotation processor."
        ),
        _PROVIDERS: "The list of all providers to propagate.",
    },
)

# Path used when resources have not been defined.
_NO_RESOURCES_PATH = "/tmp/no_resources"

def _copy_annotation_file(ctx, output_dir, annotation_template):
    annotation_out = ctx.actions.declare_file(
        output_dir + "/android/databinding/layouts/DataBindingInfo.java",
    )
    _utils.copy_file(ctx, annotation_template, annotation_out)
    return annotation_out

def _gen_sources(ctx, output_dir, java_package, deps, data_binding_exec):
    layout_info = ctx.actions.declare_file(output_dir + "layout-info.zip")
    class_info = ctx.actions.declare_file(output_dir + "class-info.zip")
    srcjar = ctx.actions.declare_file(output_dir + "baseClassSrc.srcjar")

    args = ctx.actions.args()
    args.add("-layoutInfoFiles", layout_info)
    args.add("-package", java_package)
    args.add("-classInfoOut", class_info)
    args.add("-sourceOut", srcjar)
    args.add("-zipSourceOutput", "true")
    args.add("-useAndroidX", "false")

    class_infos = []
    for info in deps:
        class_infos.extend(info.class_infos)
    args.add_all(class_infos, before_each = "-dependencyClassInfoList")

    ctx.actions.run(
        executable = data_binding_exec,
        arguments = ["GEN_BASE_CLASSES", args],
        inputs = class_infos + [layout_info],
        outputs = [class_info, srcjar],
        mnemonic = "GenerateDataBindingBaseClasses",
        progress_message = (
            "GenerateDataBindingBaseClasses %s" % class_info.short_path
        ),
    )
    return srcjar, class_info, layout_info

def _setup_dependent_lib_artifacts(ctx, output_dir, deps):
    # DataBinding requires files in very specific locations.
    # The following expand_template (copy actions) are moving the files
    # to the correct locations.
    dep_lib_artifacts = []
    for info in deps:
        # Yes, DataBinding requires depsets iterations.
        for artifact in (info.transitive_br_files.to_list() +
                         info.setter_stores +
                         info.class_infos):
            # short_path might contain a parent directory reference if the
            # databinding artifact is from an external repository (e.g. an aar
            # from Maven). If that's the case, just remove the parent directory
            # reference, otherwise the "dependent-lib-artifacts" directory will
            # get removed by the "..".
            path = artifact.short_path
            if path.startswith("../"):
                path = path[3:]
            dep_lib_artifact = ctx.actions.declare_file(
                output_dir + "dependent-lib-artifacts/" + path,
            )

            # Copy file to a location required by the DataBinding annotation
            # processor.
            # TODO(djwhang): Look into SymlinkAction.
            if artifact.is_directory:
                _utils.copy_dir(ctx, artifact, dep_lib_artifact)
            else:
                _utils.copy_file(ctx, artifact, dep_lib_artifact)
            dep_lib_artifacts.append(dep_lib_artifact)
    return dep_lib_artifacts

def _get_javac_opts(
        ctx,
        java_package,
        dependency_artifacts_dir,
        aar_out_dir,
        class_info_path,
        layout_info_path,
        deps):
    java_packages = []
    for info in deps:
        for label_and_java_package in info.label_and_java_packages:
            java_packages.append(label_and_java_package.java_package)

    javac_opts = []
    javac_opts.append("-Aandroid.databinding.dependencyArtifactsDir=" +
                      dependency_artifacts_dir)
    javac_opts.append("-Aandroid.databinding.aarOutDir=" + aar_out_dir)
    javac_opts.append("-Aandroid.databinding.sdkDir=/not/used")
    javac_opts.append("-Aandroid.databinding.artifactType=LIBRARY")
    javac_opts.append("-Aandroid.databinding.exportClassListOutFile=" +
                      "/tmp/exported_classes")
    javac_opts.append("-Aandroid.databinding.modulePackage=" + java_package)
    javac_opts.append("-Aandroid.databinding.directDependencyPkgs=[%s]" %
                      ",".join(java_packages))

    # The minimum Android SDK compatible with this rule.
    # TODO(djwhang): This probably should be based on the actual min-sdk from
    # the manifest, or an appropriate rule attribute.
    javac_opts.append("-Aandroid.databinding.minApi=14")
    javac_opts.append("-Aandroid.databinding.enableV2=1")

    javac_opts.append("-Aandroid.databinding.classLogDir=" + class_info_path)
    javac_opts.append("-Aandroid.databinding.layoutInfoDir=" + layout_info_path)
    return javac_opts

def _process(
        ctx,
        resources_ctx = None,
        defines_resources = False,
        enable_data_binding = False,
        java_package = None,
        deps = [],
        exports = [],
        data_binding_exec = None,
        data_binding_annotation_processor = None,
        data_binding_annotation_template = None):
    """Processes Android Data Binding.

    Args:
      ctx: The context.
      resources_ctx: The Android Resources context.
      defines_resources: boolean. Determines whether resources were defined.
      enable_data_binding: boolean. Determines whether Data Binding should be
        enabled.
      java_package: String. The Java package.
      deps: sequence of DataBindingV2Info providers. A list of deps. Optional.
      exports: sequence of DataBindingV2Info providers. A list of exports.
        Optional.
      data_binding_exec: The DataBinding executable.
      data_binding_annotation_processor: JavaInfo. The JavaInfo for the
        annotation processor.
      data_binding_annotation_template: A file. Used to generate data binding
        classes.

    Returns:
      A DataBindingContextInfo provider.
    """

    # TODO(b/154513292): Clean up bad usages of context objects.
    if resources_ctx:
        defines_resources = resources_ctx.defines_resources

    # The Android Data Binding context object.
    db_info = {
        _JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_INPUTS: [],
        _JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_OUTPUTS: [],
        _JAVA_PLUGINS: [],
        _JAVA_SRCS: [],
        _JAVAC_OPTS: [],
        _PROVIDERS: [],
    }

    if not enable_data_binding:
        db_info[_PROVIDERS] = [
            DataBindingV2Info(
                databinding_v2_providers_in_deps = deps,
                databinding_v2_providers_in_exports = exports,
            ),
        ]
        return struct(**db_info)

    output_dir = "_migrated/databinding/%s/" % ctx.label.name

    db_info[_JAVA_SRCS].append(_copy_annotation_file(
        ctx,
        output_dir,
        data_binding_annotation_template,
    ))
    db_info[_JAVA_PLUGINS].append(data_binding_annotation_processor)

    br_out = None
    setter_store_out = None
    class_info = None
    layout_info = None
    if defines_resources:
        # Outputs of the Data Binding annotation processor.
        br_out = ctx.actions.declare_file(
            output_dir + "bin-files/%s-br.bin" % java_package,
        )
        db_info[_JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_OUTPUTS].append(br_out)
        setter_store_out = ctx.actions.declare_file(
            output_dir + "bin-files/%s-setter_store.json" % java_package,
        )
        db_info[_JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_OUTPUTS].append(
            setter_store_out,
        )

        srcjar, class_info, layout_info = _gen_sources(
            ctx,
            output_dir,
            java_package,
            deps,
            data_binding_exec,
        )
        db_info[_JAVA_SRCS].append(srcjar)
        db_info[_JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_INPUTS].append(class_info)
        db_info[_JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_INPUTS].append(
            layout_info,
        )

    dep_lib_artifacts = _setup_dependent_lib_artifacts(ctx, output_dir, deps)
    db_info[_JAVA_ANNOTATION_PROCESSOR_ADDITIONAL_INPUTS].extend(
        dep_lib_artifacts,
    )

    db_info[_JAVAC_OPTS] = _get_javac_opts(
        ctx,
        java_package,
        (
            br_out.path.rpartition(br_out.short_path)[0] +
            ctx.label.package +
            "/" +
            output_dir +
            "dependent-lib-artifacts"
        ),
        br_out.dirname,
        class_info.path if class_info else _NO_RESOURCES_PATH,
        layout_info.path if layout_info else _NO_RESOURCES_PATH,
        deps,
    )

    db_info[_PROVIDERS] = [
        DataBindingV2Info(
            setter_store_file = setter_store_out,
            class_info_file = class_info,
            br_file = br_out,
            label = str(ctx.label),
            java_package = java_package,
            databinding_v2_providers_in_deps = deps,
            databinding_v2_providers_in_exports = exports,
        ),
    ]

    return DataBindingContextInfo(**db_info)

data_binding = struct(
    process = _process,
)
