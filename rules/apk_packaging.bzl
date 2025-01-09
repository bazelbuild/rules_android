# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""Defines Bazel Apk processing methods for Android rules."""

load("//providers:providers.bzl", "ApkInfo")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":java.bzl", "java")

visibility(PROJECT_VISIBILITY)

_PROVIDERS = "providers"
_IMPLICIT_OUTPUTS = "implicit_outputs"
_OUTPUT_GROUPS = "output_groups"
_SIGNED_APK = "signed_apk"

_ApkContextInfo = provider(
    "Apk Context Info",
    fields = {
        _PROVIDERS: "The list of all providers to propagate.",
        _IMPLICIT_OUTPUTS: "List of implicit outputs to be built as part of the top-level target.",
        _OUTPUT_GROUPS: "A dictionary of output groups to propagate",
        _SIGNED_APK: "The signed APK.",
    },
)

def _process(
        ctx,
        unsigned_apk,
        signed_apk,
        resources_apk,
        final_classes_dex_zip,
        deploy_jar,
        native_libs = dict(),
        native_libs_aars = dict(),
        native_libs_name = None,
        coverage_metadata = None,
        merged_manifest = None,
        art_profile_zip = None,
        java_resources_zip = None,
        compress_java_resources = True,
        nocompress_extensions = [],
        output_jar_creator = "",
        signing_keys = [],
        signing_lineage = None,
        signing_key_rotation_min_sdk = None,
        stamp_signing_key = None,
        deterministic_signing = False,
        java_toolchain = None,
        deploy_info_writer = None,
        zip_aligner = None,
        apk_signer = None,
        resource_extractor = None,
        toolchain_type = None):
    """Processes Android Apk Packaging.

    Attrs:
        ctx: The rules context.
        unsigned_apk: File. The unsigned apk.
        signed_apk: File. The final signed apk.
        resources_apk: File. The resources apk.
        final_classes_dex_zip: File. The zip file containing the final dex classes.
        deploy_jar: File. The deploy jar.
        native_libs: Dict. A map from architecture to the native libraries (.so) used in this architecture.
        native_libs_aars: Depset of Files. The transitive native libraries.
        native_libs_name: File. A file containing the names of native libraries.
        coverage_metadata: File. A jar containing uninstrumented bytecode.
        merged_manifest: File. The merged manifest file.
        art_profile_zip: File. The final ART profile zip.
        java_resources_zip: File. The file containing java resources to be copied into the APK.
        compress_java_resources: Boolean. Whether to compress java resources when packaging the APK.
        nocompress_extensions: Sequence of Strings. File extensions to leave uncompressed in the APK.
        output_jar_creator: String. The name of the creator that generates the APK. E.g. "Bazel", "SingleJar".
        signing_keys: Sequence of Files. The keystores to be used to sign the APK.
        signing_lineage: File. The signing lineage for signing_keys.
        signing_key_rotation_min_sdk: The minimum API version for signing the APK with key rotation.
        stamp_signing_key: File. The keystore to be used to sign the APK with stamp signing.
        deterministic_signing: Boolean. Whether to enable deterministic DSA signing.
        java_toolchain: The JavaToolchain target.
        deploy_info_writer: FilesToRunProvider. The executable to write the deploy info proto file.
        zip_aligner: FilesToRunProvider. The executable to zipalign the APK.
        apk_signer: FilesToRunProvider. The executable to sign the APK.
        resource_extractor: FilesToRunProvider. The executable to run the resource extractor binary.
        toolchain_type: String. The Android toolchain type.

    Return:
        A struct containing all of the requested outputs and providers.
    """
    apk_packaging_ctx = {_PROVIDERS: [], _IMPLICIT_OUTPUTS: []}
    _build_apk(
        ctx,
        unsigned_apk,
        resources_apk = resources_apk,
        final_classes_dex_zip = final_classes_dex_zip,
        native_libs = native_libs,
        native_libs_aars = native_libs_aars,
        native_libs_name = native_libs_name,
        art_profile_zip = art_profile_zip,
        java_resources_zip = java_resources_zip,
        compress_java_resources = compress_java_resources,
        nocompress_extensions = nocompress_extensions,
        output_jar_creator = output_jar_creator,
        java_toolchain = java_toolchain,
        resource_extractor = resource_extractor,
        toolchain_type = toolchain_type,
    )
    apk_packaging_ctx[_IMPLICIT_OUTPUTS].append(unsigned_apk)

    # TODO(b/309949683): Consider removing the zipalign action.
    zipaligned_apk = ctx.actions.declare_file("zipaligned_" + signed_apk.basename)
    _zipalign_apk(
        ctx,
        out_apk = zipaligned_apk,
        in_apk = unsigned_apk,
        zip_aligner = zip_aligner,
        toolchain_type = toolchain_type,
    )

    v4_signature_file = None
    if ctx.fragments.android.apk_signing_method_v4:
        v4_signature_file = ctx.actions.declare_file(signed_apk.basename + ".idsig")
        apk_packaging_ctx[_IMPLICIT_OUTPUTS].append(v4_signature_file)

    _sign_apk(
        ctx,
        out_apk = signed_apk,
        in_apk = zipaligned_apk,
        signing_keys = signing_keys,
        stamp_signing_key = stamp_signing_key,
        deterministic_signing = deterministic_signing,
        signing_lineage = signing_lineage,
        signing_key_rotation_min_sdk = signing_key_rotation_min_sdk,
        v4_signature_file = v4_signature_file,
        apk_signer = apk_signer,
        toolchain_type = toolchain_type,
    )

    apk_packaging_ctx[_SIGNED_APK] = signed_apk
    apk_packaging_ctx[_IMPLICIT_OUTPUTS].append(signed_apk)

    deploy_info = ctx.actions.declare_file(ctx.label.name + "_files/deploy_info.deployinfo.pb")
    _create_deploy_info(
        ctx,
        deploy_info,
        manifest = merged_manifest,
        apks_to_deploy = [signed_apk] + ([v4_signature_file] if v4_signature_file else []),
        deploy_info_writer = deploy_info_writer,
        toolchain_type = toolchain_type,
    )

    apk_packaging_ctx[_PROVIDERS].append(
        ApkInfo(
            signed_apk = signed_apk,
            unsigned_apk = unsigned_apk,
            deploy_jar = deploy_jar,
            coverage_metadata = coverage_metadata,
            signing_keys = signing_keys,
            signing_lineage = signing_lineage,
            signing_min_v3_rotation_api_version = signing_key_rotation_min_sdk,
            keystore = signing_keys[0] if signing_keys else None,
        ),
    )
    apk_packaging_ctx[_OUTPUT_GROUPS] = dict(
        android_deploy_info = [
            deploy_info,
            merged_manifest,
        ],
    )

    return _ApkContextInfo(**apk_packaging_ctx)

def _build_apk(
        ctx,
        out_apk,
        resources_apk = None,
        final_classes_dex_zip = None,
        native_libs = dict(),
        native_libs_aars = dict(),
        native_libs_name = None,
        art_profile_zip = None,
        java_resources_zip = None,
        compress_java_resources = False,
        nocompress_extensions = [],
        output_jar_creator = None,
        resource_extractor = None,
        toolchain_type = None,
        java_toolchain = None):
    """Builds an unsigned APK using SingleJar."""

    compressed_apk = ctx.actions.declare_file("compressed_" + out_apk.basename)
    extracted_java_resources_zip = None
    inputs = [final_classes_dex_zip]

    if java_resources_zip:
        extracted_java_resources_zip = ctx.actions.declare_file("extracted_" + java_resources_zip.basename)
        _extract_resources(
            ctx,
            output = extracted_java_resources_zip,
            java_resources_zip = java_resources_zip,
            resource_extractor = resource_extractor,
            toolchain_type = toolchain_type,
        )

    if compress_java_resources and extracted_java_resources_zip:
        inputs.append(extracted_java_resources_zip)

    resources = []
    resource_paths = []
    for architecture in native_libs:
        for native_lib in native_libs[architecture].to_list():
            path = "%s:lib/%s/%s" % (native_lib.path, architecture, native_lib.basename)
            resources.append(native_lib)
            resource_paths.append(path)

    java.singlejar(
        ctx,
        inputs = inputs,
        output = compressed_apk,
        mnemonic = "ApkBuilder",
        progress_message = "Generating unsigned apk",
        resources = resources,
        resource_paths = resource_paths,
        nocompress_suffixes = nocompress_extensions,
        output_jar_creator = output_jar_creator,
        java_toolchain = java_toolchain,
    )

    inputs = [compressed_apk]
    if not compress_java_resources and extracted_java_resources_zip:
        inputs.append(extracted_java_resources_zip)

    # Resources apk must appear after extracted Java resources due to some teams hacking the build
    # and supplying their own resources.arsc via a java_import. In the case of duplicates, the
    # singlejar action will take the first version of a file it sees.
    inputs.append(resources_apk)

    if art_profile_zip:
        inputs.append(art_profile_zip)

    resources = []
    resource_paths = []
    if native_libs_name:
        resources = [native_libs_name]
        resource_paths = ["%s:%s" % (native_libs_name.path, native_libs_name.basename)]

    java.singlejar(
        ctx,
        inputs = depset(inputs, transitive = native_libs_aars.values()),
        output = out_apk,
        mnemonic = "ApkBuilder",
        progress_message = "Generating unsigned apk",
        resources = resources,
        resource_paths = resource_paths,
        nocompress_suffixes = nocompress_extensions,
        output_jar_creator = output_jar_creator,
        compression = False,
        preserve_compression = True,
        java_toolchain = java_toolchain,
    )

def _extract_resources(
        ctx,
        output = None,
        java_resources_zip = None,
        resource_extractor = None,
        toolchain_type = None):
    """Extracts Java resources to be packaged in the APK."""
    args = ctx.actions.args()
    args.add(java_resources_zip)
    args.add(output)

    ctx.actions.run(
        executable = resource_extractor,
        arguments = [args],
        mnemonic = "ResourceExtractor",
        progress_message = "Extracting Java resources from deploy jar for apk",
        inputs = [java_resources_zip],
        outputs = [output],
        use_default_shell_env = True,
        toolchain = toolchain_type,
    )

def _zipalign_apk(
        ctx,
        out_apk = None,
        in_apk = None,
        zip_aligner = None,
        toolchain_type = None):
    """ Zipaligns an unsigned apk."""
    args = ctx.actions.args()
    args.add("-p", "4")
    args.add(in_apk)
    args.add(out_apk)

    ctx.actions.run(
        executable = zip_aligner,
        inputs = [in_apk],
        outputs = [out_apk],
        arguments = [args],
        mnemonic = "AndroidZipAlign",
        progress_message = "Zipaligning apk",
        toolchain = toolchain_type,
    )

def _sign_apk(
        ctx,
        out_apk,
        in_apk,
        signing_keys = [],
        stamp_signing_key = None,
        deterministic_signing = True,
        signing_lineage = None,
        signing_key_rotation_min_sdk = None,
        v4_signature_file = None,
        apk_signer = None,
        toolchain_type = None):
    """Signs an apk."""
    outputs = [out_apk]
    inputs = [in_apk] + signing_keys

    args = ctx.actions.args()
    args.add("sign")

    if signing_lineage:
        inputs.append(signing_lineage)
        args.add("--lineage", signing_lineage)
    if deterministic_signing:
        # Enable deterministic DSA signing to keep the output of apksigner deterministic.
        # This requires including BouncyCastleProvider as a Security provider, since the standard
        # JDK Security providers do not include support for deterministic DSA signing.
        # Since this adds BouncyCastleProvider to the end of the Provider list, any non-DSA signing
        # algorithms (such as RSA) invoked by apksigner will still use the standard JDK
        # implementations and not Bouncy Castle.
        args.add("--deterministic-dsa-signing", "true")
        args.add("--provider-class", "org.bouncycastle.jce.provider.BouncyCastleProvider")

    for i in range(len(signing_keys)):
        if i > 0:
            args.add("--next-signer")
        args.add("--ks", signing_keys[i])
        args.add("--ks-pass", "pass:android")

    args.add("--v1-signing-enabled", ctx.fragments.android.apk_signing_method_v1)
    args.add("--v1-signer-name", "CERT")
    args.add("--v2-signing-enabled", ctx.fragments.android.apk_signing_method_v2)

    # If the v4 flag is unset, it should not be passed to apk signer. This extra level of control is
    # needed to support environments where older build tools may be used.
    if ctx.fragments.android.apk_signing_method_v4 != None:
        args.add("--v4-signing-enabled", ctx.fragments.android.apk_signing_method_v4)
    if v4_signature_file:
        outputs.append(v4_signature_file)

    if signing_key_rotation_min_sdk:
        args.add("--rotation-min-sdk-version", signing_key_rotation_min_sdk)

    if stamp_signing_key:
        inputs.append(stamp_signing_key)
        args.add("--stamp-signer")
        args.add("--ks", stamp_signing_key)
        args.add("--ks-pass", "pass:android")

    args.add("--out", out_apk)
    args.add(in_apk)

    ctx.actions.run(
        executable = apk_signer,
        outputs = outputs,
        inputs = inputs,
        arguments = [args],
        mnemonic = "ApkSignerTool",
        progress_message = "Signing apk",
        toolchain = toolchain_type,
    )

def _create_deploy_info(
        ctx,
        deploy_info,
        manifest = None,
        apks_to_deploy = [],
        deploy_info_writer = None,
        toolchain_type = None):
    """Creates a deploy info proto."""
    args = ctx.actions.args()
    args.add("--manifest", manifest)
    args.add_joined("--apk", apks_to_deploy, join_with = ",")
    args.add("--deploy_info", deploy_info)

    ctx.actions.run(
        executable = deploy_info_writer,
        arguments = [args],
        outputs = [deploy_info],
        mnemonic = "WriteDeployInfo",
        progress_message = "Writing Deploy info proto file %s" % deploy_info.short_path,
        toolchain = toolchain_type,
    )

apk_packaging = struct(
    process = _process,
)
