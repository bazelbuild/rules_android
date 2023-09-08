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

def _generate_sdk_dependencies_manifest(
        ctx,
        output = None,
        manifest_package = None,
        sdk_module_configs = None,
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
      debug_key: Keystore that will later be used to sign the SDK APKs. It's expected to be a
      sandboxed_sdk_toolbox: Toolbox executable files.
      host_javabase: Javabase used to run the toolbox.
    """
    args = ctx.actions.args()
    args.add("generate-sdk-dependencies-manifest")
    args.add("--manifest-package", manifest_package)
    args.add("--sdk-module-configs", ",".join([config.path for config in sdk_module_configs]))
    args.add("--debug-keystore", debug_key)
    args.add("--debug-keystore-pass", "android")
    args.add("--debug-keystore-alias", "androiddebugkey")
    args.add("--output-manifest", output)
    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = sandboxed_sdk_toolbox,
        arguments = [args],
        inputs = sdk_module_configs + [debug_key],
        outputs = [output],
        mnemonic = "GenSdkDepManifest",
        progress_message = "Generate SDK dependencies manifest %s" % output.short_path,
    )

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

sandboxed_sdk_toolbox = struct(
    extract_api_descriptors = _extract_api_descriptors,
    generate_sdk_dependencies_manifest = _generate_sdk_dependencies_manifest,
)
