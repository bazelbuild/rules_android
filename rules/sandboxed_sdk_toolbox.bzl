# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Bazel SandboxedSdkToolbox commands."""

load(":java.bzl", _java = "java")

def _extract_api_descriptors(
        ctx,
        output = None,
        sdk_deploy_jar = None,
        sandboxed_sdk_toolbox = None,
        host_javabase = None):
    """Extracts API descriptors from a sandboxed SDK classpath.

    The API descriptors can later be used to generate sources for communicating with this SDK.

    Args:
      ctx: The context.
      output: Output API descriptors jar file.
      sdk_deploy_jar: The SDK classpath, with transitive dependencies.
      sandboxed_sdk_toolbox: Toolbox executable files.
      host_javabase: Javabase used to run the toolbox.
    """
    args = ctx.actions.args()
    args.add("extract-api-descriptors")
    args.add("--sdk-deploy-jar", sdk_deploy_jar)
    args.add("--output-sdk-api-descriptors", output)
    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = sandboxed_sdk_toolbox,
        arguments = [args],
        inputs = [sdk_deploy_jar],
        outputs = [output],
        mnemonic = "ExtractApiDescriptors",
        progress_message = "Extract SDK API descriptors %s" % output.short_path,
    )

def _extract_api_descriptors_from_asar(
        ctx,
        output = None,
        asar = None,
        sandboxed_sdk_toolbox = None,
        host_javabase = None):
    """Extracts API descriptors from a sandboxed SDK archive.

    The API descriptors can later be used to generate sources for communicating with this SDK.

    Args:
      ctx: The context.
      output: Output API descriptors jar file.
      asar: The sandboxed sdk archive.
      sandboxed_sdk_toolbox: Toolbox executable files.
      host_javabase: Javabase used to run the toolbox.
    """
    args = ctx.actions.args()
    args.add("extract-api-descriptors-from-asar")
    args.add("--asar", asar)
    args.add("--output-sdk-api-descriptors", output)
    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = sandboxed_sdk_toolbox,
        arguments = [args],
        inputs = [asar],
        outputs = [output],
        mnemonic = "ExtractApiDescriptorsFromAsar",
        progress_message = "Extract SDK API descriptors from ASAR %s" % output.short_path,
    )

def _generate_client_sources(
        ctx,
        output_kotlin_dir = None,
        output_java_dir = None,
        sdk_api_descriptors = None,
        aidl_compiler = None,
        framework_aidl = None,
        sandboxed_sdk_toolbox = None,
        host_javabase = None):
    """Generate Kotlin and Java sources for SDK communication.

    Args:
      ctx: The context.
      output_kotlin_dir: Directory for Kotlin source tree. It depends on the Java sources.
      output_java_dir: Directory for Java source tree. Doesn't depend on Kotlin sources.
      sdk_api_descriptors: SDK API descriptor jar.
      aidl_compiler: Executable files for the AOSP AIDL compiler.
      framework_aidl: Framework.aidl file used to compile AIDL sources.
      sandboxed_sdk_toolbox: Toolbox executable files.
      host_javabase: Javabase used to run the toolbox.
    """
    args = ctx.actions.args()
    args.add("generate-client-sources")
    args.add("--sdk-api-descriptors", sdk_api_descriptors)
    args.add("--aidl-compiler", aidl_compiler)
    args.add("--framework-aidl", framework_aidl)
    args.add("--output-kotlin-dir", output_kotlin_dir.path)
    args.add("--output-java-dir", output_java_dir.path)
    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = sandboxed_sdk_toolbox,
        arguments = [args],
        inputs = [
            sdk_api_descriptors,
            aidl_compiler,
            framework_aidl,
        ],
        outputs = [output_kotlin_dir, output_java_dir],
        mnemonic = "GenClientSources",
        progress_message = "Generate client sources for %s" % output_kotlin_dir.short_path,
    )

def _generate_runtime_enabled_sdk_config(
        ctx,
        output = None,
        manifest_xml_tree = None,
        sdk_module_configs = None,
        sdk_archives = None,
        debug_key = None,
        sandboxed_sdk_toolbox = None,
        host_javabase = None):
    inputs = [debug_key, manifest_xml_tree]
    args = ctx.actions.args()
    args.add("generate-runtime-enabled-sdk-config")
    args.add("--manifest-xml-tree", manifest_xml_tree)
    if sdk_module_configs:
        args.add("--sdk-module-configs", ",".join([config.path for config in sdk_module_configs]))
        inputs.extend(sdk_module_configs)
    if sdk_archives:
        args.add("--sdk-archives", ",".join([archive.path for archive in sdk_archives]))
        inputs.extend(sdk_archives)
    args.add("--debug-keystore", debug_key)
    args.add("--debug-keystore-pass", "android")
    args.add("--debug-keystore-alias", "androiddebugkey")
    args.add("--output-config", output)
    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = sandboxed_sdk_toolbox,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = "GenRuntimeEnabledSdkConfig",
        progress_message = "Generate RuntimeEnabledSdkConfig proto message %s" % output.short_path,
    )

def _generate_runtime_enabled_sdk_table(
        ctx,
        output = None,
        sdk_archives = None,
        sdk_module_configs = None,
        sandboxed_sdk_toolbox = None,
        host_javabase = None):
    """Generates a XML file with metadata expected by the SDK Runtime library.

    This will be used to load sandboxed SDKs in compatibility mode on devices without the sandbox.

    Args:
      ctx: The context.
      output: Output XML file.
      sdk_archives: List of SDK archives, as ASAR files. They will also be listed as dependencies.
      sdk_module_configs: List of SDK Module config JSON files with SDK packages and versions.
      sandboxed_sdk_toolbox: Toolbox executable files.
      host_javabase: Javabase used to run the toolbox.
    """
    inputs = []
    args = ctx.actions.args()
    args.add("generate-runtime-enabled-sdk-table")
    if sdk_module_configs:
        args.add("--sdk-module-configs", ",".join([config.path for config in sdk_module_configs]))
        inputs.extend(sdk_module_configs)
    if sdk_archives:
        args.add("--sdk-archives", ",".join([archive.path for archive in sdk_archives]))
        inputs.extend(sdk_archives)
    args.add("--output-table", output)
    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = sandboxed_sdk_toolbox,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = "GenRuntimeEnabledSdkTable",
        progress_message = "Generate SDK dependencies XML metadata for app %s" % output.short_path,
    )

def _generate_sdk_dependencies_manifest(
        ctx,
        output = None,
        manifest_package = None,
        sdk_module_configs = None,
        sdk_archives = None,
        debug_key = None,
        sandboxed_sdk_toolbox = None,
        host_javabase = None):
    """Generates a manifest that lists all sandboxed SDK dependencies.

    The generated manifest will contain <uses-sdk-library> tags for each SDK. This is required for
    loading the SDK in the Privacy Sandbox.

    Args:
      ctx: The context.
      output: File where the final manifest will be written.
      manifest_package: The package used in the manifest.
      sdk_module_configs: List of SDK Module config JSON files with SDK packages and versions.
      sdk_archives: List of SDK archives, as ASAR files. They will also be listed as dependencies.
      debug_key: Debug keystore that will later be used to sign the SDK APKs.
      sandboxed_sdk_toolbox: Toolbox executable files.
      host_javabase: Javabase used to run the toolbox.
    """
    inputs = [debug_key]
    args = ctx.actions.args()
    args.add("generate-sdk-dependencies-manifest")
    args.add("--manifest-package", manifest_package)
    if sdk_module_configs:
        args.add("--sdk-module-configs", ",".join([config.path for config in sdk_module_configs]))
        inputs.extend(sdk_module_configs)
    if sdk_archives:
        args.add("--sdk-archives", ",".join([archive.path for archive in sdk_archives]))
        inputs.extend(sdk_archives)
    args.add("--debug-keystore", debug_key)
    args.add("--debug-keystore-pass", "android")
    args.add("--debug-keystore-alias", "androiddebugkey")
    args.add("--output-manifest", output)
    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = sandboxed_sdk_toolbox,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = "GenSdkDepManifest",
        progress_message = "Generate SDK dependencies manifest %s" % output.short_path,
    )

def _generate_sdk_split_properties(
        ctx,
        output = None,
        sdk_archive = None,
        sdk_module_config = None,
        runtime_enabled_sdk_config = None,
        manifest_xml_tree = None,
        sandboxed_sdk_toolbox = None,
        host_javabase = None):
    """Generates the SdkSplitPropertiesInheritiedFromApp proto message.

    This message is used by Bundletool to create an app split that contains the sandboxed SDK.
    This is the deployment format of sandboxed SDKs on devices that don't have the Privacy Sandbox.

    Args:
      ctx: The context.
      output: File where the final manifest will be written.
      sdk_archive: SDK archive as an ASAR file. Exactly one of sdk_archive or sdk_module_config
        must be set.
      sdk_module_config: SDK Module config JSON file form an SDK bundle. Exactly one of sdk_archive
        or sdk_module_config must be set.
      runtime_enabled_sdk_config: A RuntimeEnabledSdkConfig file with all the SDKs targeted by the
        host app, including the target SDK.
      manifest_xml_tree: A file with the AAPT2's xmltree dump of the host app manifest.
        This will be used to read the app id, version code and minSdkVersion.
      sandboxed_sdk_toolbox: Toolbox executable files.
      host_javabase: Javabase used to run the toolbox.
    """
    if (bool(sdk_archive) == bool(sdk_module_config)):
        fail("Exactly one of sdk_archive or sdk_module_config must be set in %s" % ctx.label.name)
    inputs = [runtime_enabled_sdk_config, manifest_xml_tree]
    args = ctx.actions.args()
    args.add("generate-sdk-split-properties")
    args.add("--runtime-enabled-sdk-config", runtime_enabled_sdk_config)
    args.add("--manifest-xml-tree", manifest_xml_tree)
    if sdk_module_config:
        args.add("--sdk-modules-config", sdk_module_config)
        inputs.append(sdk_module_config)
    if sdk_archive:
        args.add("--sdk-archive", sdk_archive)
        inputs.append(sdk_archive)
    args.add("--output-properties", output)
    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = sandboxed_sdk_toolbox,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = "GenSdkSplitProperties",
        progress_message = "Generate SDK split properties %s" % output.short_path,
    )

sandboxed_sdk_toolbox = struct(
    extract_api_descriptors = _extract_api_descriptors,
    extract_api_descriptors_from_asar = _extract_api_descriptors_from_asar,
    generate_client_sources = _generate_client_sources,
    generate_runtime_enabled_sdk_config = _generate_runtime_enabled_sdk_config,
    generate_runtime_enabled_sdk_table = _generate_runtime_enabled_sdk_table,
    generate_sdk_dependencies_manifest = _generate_sdk_dependencies_manifest,
    generate_sdk_split_properties = _generate_sdk_split_properties,
)
