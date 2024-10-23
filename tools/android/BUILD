load("@rules_java//java:defs.bzl", "java_binary", "java_library", "java_plugin")
load("@rules_python//python:defs.bzl", "py_binary", "py_library", "py_test")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("//rules:min_sdk_version.bzl", "min_sdk_version")
load(":defs.bzl", "android_jar", "run_ijar", "run_singlejar")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

config_setting(
    name = "minimal_desugaring",
    values = {
        "define": "java8_library_desugaring=minimal",
    },
)

config_setting(
    name = "full_desugaring",
    values = {
        "define": "java8_library_desugaring=full",
    },
)

android_jar(
    name = "android_jar",
    visibility = ["//visibility:public"],
)

# TODO(b/175833857): This is a stub, should remove.
alias(
    name = "merge_manifests",
    actual = ":fail",
    visibility = ["//visibility:public"],
)

genrule(
    name = "gen_fail",
    outs = ["fail.sh"],
    cmd = "echo 'exit 1' > $@",
    executable = 1,
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "fail",
    srcs = [":fail.sh"],
)

java_binary(
    name = "bundletool",
    main_class = "com.android.tools.build.bundletool.BundleToolMain",
    visibility = ["//visibility:public"],
    runtime_deps = ["@rules_android_maven//:com_android_tools_build_bundletool"],
)

java_plugin(
    name = "compiler_annotation_processor",
    generates_api = True,
    processor_class = "android.databinding.annotationprocessor.ProcessDataBinding",
    visibility = ["//visibility:public"],
    deps = [
        "//src/tools/java/com/google/devtools/build/android:databinding_exec_jar",
    ],
)

alias(
    name = "zip",
    actual = "//toolchains/android:zip",
    visibility = ["//visibility:public"],
)

genrule(
    name = "full_desugar_jdk_libs_config_json",
    srcs = [
        "@rules_android_maven//:com_android_tools_desugar_jdk_libs_configuration_nio",
    ],
    outs = ["full_desugar_jdk_libs_config.json"],
    cmd = "unzip -q -c " +
          "$(location @rules_android_maven//:com_android_tools_desugar_jdk_libs_configuration_nio) " +
          "META-INF/desugar/d8/desugar.json > $@",
)

genrule(
    name = "minimal_desugar_jdk_libs_config_json",
    srcs = [
        "@rules_android_maven//:com_android_tools_desugar_jdk_libs_configuration_minimal",
    ],
    outs = ["minimal_desugar_jdk_libs_config.json"],
    cmd = "unzip -q -c " +
          "$(location @rules_android_maven//:com_android_tools_desugar_jdk_libs_configuration_minimal) " +
          "META-INF/desugar/d8/desugar.json > $@",
)

genrule(
    name = "desugar_jdk_libs_json",
    srcs = select({
        "full_desugaring": [":full_desugar_jdk_libs_config_json"],
        "minimal_desugaring": [":minimal_desugar_jdk_libs_config_json"],
        "//conditions:default": [":full_desugar_jdk_libs_config_json"],
    }),
    outs = ["desugar_jdk_libs.json"],
    cmd = "cp $< $@",
)

genrule(
    name = "minify_desugar_jdk_libs_pgcfg",
    srcs = [
        "//src/tools/extract_desugar_pgcfg_flags",
        ":desugar_jdk_libs_json",
    ],
    outs = ["minify_desugar_jdk_libs.pgcfg"],
    cmd = "$(location //src/tools/extract_desugar_pgcfg_flags) --input_json $(location :desugar_jdk_libs_json) --output_file $@",
)

genrule(
    name = "build_java8_legacy_dex_params",
    outs = ["build_java8_legacy_dex_params.txt"],
    cmd = "echo -n --min-api 19 > $@",
    visibility = ["//visibility:private"],
)

genrule(
    name = "desugared_jdk_libs_from_maven_jar",
    srcs = select({
        "full_desugaring": ["@rules_android_maven//:com_android_tools_desugar_jdk_libs_nio"],
        "minimal_desugaring": ["@rules_android_maven//:com_android_tools_desugar_jdk_libs_minimal"],
        "//conditions:default": ["@rules_android_maven//:com_android_tools_desugar_jdk_libs_nio"],
    }),
    outs = ["desugared_jdk_libs_from_maven.jar"],
    cmd = "cp $< $@",
)

genrule(
    name = "desugared_jdk_libs_jar",
    srcs = [
        ":desugared_jdk_libs_from_maven.jar",
        ":full_desugar_jdk_libs_config_json",
    ],
    outs = ["desugared_jdk_libs.jar"],
    cmd = "$(location :desugar_java8) " +
          "--desugared_lib_config $(location :full_desugar_jdk_libs_config_json) " +
          "--input=$(location :desugared_jdk_libs_from_maven.jar) --output=$@",
    tools = [":desugar_java8"],
)

sh_binary(
    name = "build_java8_legacy_dex",
    srcs = ["build_java8_legacy_dex.sh"],
    data = [
        "build_java8_legacy_dex_params",
        ":d8",
        ":desugared_jdk_libs_jar",
        ":minify_desugar_jdk_libs.pgcfg",
        ":r8",
        ":tracereferences",
        ":zip",
        "@bazel_tools//tools/bash/runfiles",
    ],
    visibility = ["//visibility:public"],
)

genrule(
    name = "java8_legacy_dex",
    outs = ["java8_legacy.dex.zip"],
    cmd = "$(location :build_java8_legacy_dex) --output $@",
    tools = [":build_java8_legacy_dex"],
    visibility = ["//visibility:public"],
)

genrule(
    name = "d8_desugar_params",
    outs = ["d8_desugar_params.txt"],
    cmd = "echo -n --min_sdk_version 19 > $@",
    visibility = ["//visibility:private"],
)

sh_binary(
    name = "desugar_java8",
    srcs = [":d8_desugar.sh"],
    data = [
        ":d8_desugar_params",
        ":full_desugar_jdk_libs_config_json",
        "//src/tools/java/com/google/devtools/build/android/r8:desugar",
        "@bazel_tools//tools/bash/runfiles",
    ],
    visibility = ["//visibility:public"],
)

run_ijar(
    name = "ijar_desugared_java8_legacy_libs",
    jar = ":desugared_jdk_libs.jar",
    visibility = ["//visibility:public"],
)

java_import(
    name = "desugared_java8_legacy_apis",
    constraints = ["android"],
    jars = [":ijar_desugared_java8_legacy_libs"],
    neverlink = 1,
    visibility = ["//visibility:public"],
)

java_binary(
    name = "d8",
    main_class = "com.android.tools.r8.D8",
    visibility = ["//visibility:public"],
    runtime_deps = ["@android_gmaven_r8//jar"],
)

java_binary(
    name = "r8",
    main_class = "com.android.tools.r8.R8",
    visibility = ["//visibility:public"],
    runtime_deps = ["@android_gmaven_r8//jar"],
)

java_binary(
    name = "tracereferences",
    main_class = "com.android.tools.r8.tracereferences.TraceReferences",
    visibility = ["//visibility:public"],
    runtime_deps = ["@android_gmaven_r8//jar"],
)

java_binary(
    name = "resource_shrinker",
    main_class = "com.android.build.shrinker.ResourceShrinkerCli",
    visibility = ["//visibility:public"],
    runtime_deps = ["@rules_android_maven//:com_android_tools_build_gradle"],
)

alias(
    name = "merge_dexzips",
    actual = "//src/tools/java/com/google/devtools/build/android/ziputils:reducer",
    visibility = ["//visibility:public"],
)

alias(
    name = "shuffle_jars",
    actual = "//src/tools/java/com/google/devtools/build/android/ziputils:mapper",
    visibility = ["//visibility:public"],
)

alias(
    name = "zip_filter",
    actual = "//src/tools/java/com/google/devtools/build/android:ZipFilterAction",
    visibility = ["//visibility:public"],
)

java_binary(
    name = "databinding_exec",
    main_class = "android.databinding.AndroidDataBinding",
    visibility = ["//visibility:public"],
    runtime_deps = [
        "//src/tools/java/com/google/devtools/build/android:databinding_exec_jar",
    ],
)

# Defines d8_dexbuilder using @<repo>//:d8_jar_import generated by android_sdk_repository rule
# without needing the SDK repo's name (typically @androidsdk but not required).
java_binary(
    name = "d8_dexbuilder",
    main_class = "com.google.devtools.build.android.r8.CompatDexBuilder",
    visibility = ["//visibility:private"],
    runtime_deps = ["//src/tools/java/com/google/devtools/build/android/r8"],
)

alias(
    name = "dexbuilder",
    actual = ":d8_dexbuilder",
    visibility = ["//visibility:public"],
)

alias(
    name = "dexbuilder_after_proguard",
    actual = ":d8_dexbuilder",
    visibility = ["//visibility:public"],
)

alias(
    name = "dexsharder",
    actual = "//src/tools/java/com/google/devtools/build/android/dexer:DexFileSplitter",
    visibility = ["//visibility:public"],
)

java_binary(
    name = "d8_dexmerger",
    main_class = "com.google.devtools.build.android.r8.DexFileMerger",
    visibility = ["//visibility:private"],
    runtime_deps = ["//src/tools/java/com/google/devtools/build/android/r8"],
)

java_binary(
    name = "global_synthetics_generator",
    jvm_flags = [
        "-XX:+TieredCompilation",
        "-XX:TieredStopAtLevel=1",
        # Consistent with what we use for desugar.
        "-Xms8g",
        "-Xmx8g",
    ],
    main_class = "com.android.tools.r8.GlobalSyntheticsGenerator",
    runtime_deps = [
        "@android_gmaven_r8//jar",
    ],
)

alias(
    name = "dexmerger",
    actual = ":d8_dexmerger",
    visibility = ["//visibility:public"],
)

# Bazel puts this on the bootclasspath of android_* targets to support Java 8
# if requested.
filegroup(
    name = "desugar_java8_extra_bootclasspath",
    srcs = ["java_base_extras.jar"],
    visibility = ["//visibility:public"],
)

# javac needs this Jar to compile lambdas, method references, and type annotations.
# These classes are not part of the android.jar.
run_singlejar(
    name = "gen_java_base_extras_jar",
    srcs = [
        "@rules_java//toolchains:platformclasspath",
    ],
    out = "java_base_extras.jar",
    include_prefixes = [
        "java/lang/invoke/",
        "java/lang/annotation/",
    ],
    visibility = ["//visibility:private"],
)

sh_binary(
    name = "dex_list_obfuscator",
    srcs = ["dex_list_obfuscator.sh"],
    visibility = ["//visibility:public"],
)

# If needed, this file can be regenerated by (validity is 30 * 365 days):
# keytool -genkeypair \
#    -alias androiddebugkey \
#    -dname "CN=Android Debug, O=Android, C=US" \
#    -keystore cica \
#    -sigalg SHA256withDSA \
#    -validity 10950
filegroup(
    name = "debug_keystore",
    srcs = ["bazel_debug.keystore"],
    visibility = ["//visibility:public"],
)

py_library(
    name = "junction_lib",
    srcs = ["junction.py"],
    visibility = ["//visibility:private"],
)

py_library(
    name = "json_worker_wrapper",
    srcs = ["json_worker_wrapper.py"],
    visibility = ["//visibility:private"],
)

py_binary(
    name = "aar_embedded_jars_extractor",
    srcs = ["aar_embedded_jars_extractor.py"],
    visibility = ["//visibility:public"],
    deps = [
        ":json_worker_wrapper",
        ":junction_lib",
        "@py_absl//absl:app",
    ],
)

py_binary(
    name = "aar_embedded_proguard_extractor",
    srcs = ["aar_embedded_proguard_extractor.py"],
    visibility = ["//visibility:public"],
    deps = [
        ":json_worker_wrapper",
        ":junction_lib",
        "@py_absl//absl:app",
    ],
)

py_binary(
    name = "aar_native_libs_zip_creator",
    srcs = [
        "aar_native_libs_zip_creator.py",
    ],
    visibility = ["//visibility:public"],
    deps = [
        ":json_worker_wrapper",
        ":junction_lib",
        "@py_absl//absl:app",
    ],
)

py_binary(
    name = "aar_resources_extractor",
    srcs = ["aar_resources_extractor.py"],
    visibility = ["//visibility:public"],
    deps = [
        ":json_worker_wrapper",
        ":junction_lib",
        "@py_absl//absl:app",
    ],
)

py_test(
    name = "aar_native_libs_zip_creator_test",
    srcs = ["aar_native_libs_zip_creator_test.py"],
    deps = [":aar_native_libs_zip_creator"],
)

py_test(
    name = "aar_embedded_jars_extractor_test",
    srcs = ["aar_embedded_jars_extractor_test.py"],
    deps = [":aar_embedded_jars_extractor"],
)

py_test(
    name = "aar_embedded_proguard_extractor_test",
    srcs = ["aar_embedded_proguard_extractor_test.py"],
    deps = [":aar_embedded_proguard_extractor"],
)

py_test(
    name = "aar_resources_extractor_test",
    srcs = ["aar_resources_extractor_test.py"],
    deps = [":aar_resources_extractor"],
)

java_binary(
    name = "apkdeployer",
    main_class = "com.android.tools.deployer.DeployerRunner",
    visibility = ["//visibility:public"],
    runtime_deps = [
        "@rules_android_maven//:com_android_tools_apkdeployer_apkdeployer",
    ],
)

java_library(
    name = "auto_service_lib",
    exports = [
        "@rules_android_maven//:com_google_auto_service_auto_service",
        "@rules_android_maven//:com_google_auto_service_auto_service_annotations",
    ],
)

java_library(
    name = "autovalue_lib",
    exports = [
        ":auto_service_lib",
        "@rules_android_maven//:com_google_auto_auto_common",
    ],
)

java_plugin(
    name = "autovalue_plugin",
    processor_class = "com.google.auto.value.processor.AutoValueProcessor",
    deps = [
        "@android_tools//:all_android_tools_deploy.jar",
    ],
)

java_plugin(
    name = "auto_annotation_plugin",
    processor_class = "com.google.auto.value.processor.AutoAnnotationProcessor",
    deps = ["@android_tools//:all_android_tools_deploy.jar"],
)

java_plugin(
    name = "auto_builder_plugin",
    processor_class = "com.google.auto.value.processor.AutoBuilderProcessor",
    deps = ["@android_tools//:all_android_tools_deploy.jar"],
)

java_library(
    name = "auto_value_api",
    exports = [
        "@rules_android_maven//:com_google_auto_value_auto_value_annotations",
    ],
)

java_library(
    name = "autovalue",
    exported_plugins = [
        ":autovalue_plugin",
        ":auto_annotation_plugin",
        ":auto_builder_plugin",
    ],
    visibility = ["//src/tools/java/com/google/devtools/build/android:__subpackages__"],
    exports = [
        ":auto_value_api",
    ],
)

java_library(
    name = "error_prone_annotations",
    exports = [
        "@rules_android_maven//:com_google_errorprone_error_prone_annotations",
        "@rules_android_maven//:com_google_errorprone_error_prone_type_annotations",
    ],
)

java_library(
    name = "error_prone",
    exports = [
        ":error_prone_annotations",
        "@rules_android_maven//:com_google_errorprone_error_prone_check_api",
        "@rules_android_maven//:com_google_errorprone_error_prone_core",
    ],
)

genrule(
    name = "desugar_globals",
    outs = ["desugar.globals"],
    cmd = "$(JAVA) -jar $(location :global_synthetics_generator_deploy.jar) --min-api {} --output $@".format(min_sdk_version.DEPOT_FLOOR),
    toolchains = ["//tools/jdk:current_host_java_runtime"],
    tools = [":global_synthetics_generator_deploy.jar"],
    visibility = ["//visibility:public"],
)

genrule(
    name = "desugar_globals_dex_archive",
    srcs = [":desugar.globals"],
    outs = ["desugar_globals.zip"],
    cmd = """
      $(JAVA) -jar $(location :d8_deploy.jar) --no-desugaring --globals $(location :desugar.globals) --output $(@)
    """,
    toolchains = ["//tools/jdk:current_host_java_runtime"],
    tools = [":d8_deploy.jar"],
    visibility = ["//visibility:public"],
)

genrule(
    name = "desugar_globals_classes",
    outs = ["desugar_globals_classes.zip"],
    cmd = "$(JAVA) -jar $(location :global_synthetics_generator_deploy.jar) --min-api {} --classfile --output $@".format(min_sdk_version.DEPOT_FLOOR),
    toolchains = ["//tools/jdk:current_host_java_runtime"],
    tools = [":global_synthetics_generator_deploy.jar"],
    visibility = ["//visibility:public"],
)

genrule(
    name = "desugar_globals_jar",
    srcs = [":desugar_globals_classes.zip"],
    outs = ["desugar_globals.jar"],
    cmd = """
    tmp=$$(mktemp -d)
    unzip $(location :desugar_globals_classes.zip) -d $${tmp}
    rm $${tmp}/kind
    rm $${tmp}/compilerinfo
    mv $${tmp}/com/android/tools/r8/RecordTag.global $${tmp}/com/android/tools/r8/RecordTag.class
    mv $${tmp}/com/android/tools/r8/DesugarMethodHandlesLookup.global $${tmp}/com/android/tools/r8/DesugarMethodHandlesLookup.class
    mv $${tmp}/com/android/tools/r8/DesugarVarHandle.global $${tmp}/com/android/tools/r8/DesugarVarHandle.class
    mv $${tmp}'/com/android/tools/r8/DesugarVarHandle$$$$ExternalSyntheticBackportWithForwarding0.global' $${tmp}'/com/android/tools/r8/DesugarVarHandle$$$$ExternalSyntheticBackportWithForwarding0.class'
    out=$$(pwd)/$(@)
    cd $${tmp}
    zip -r $${out} .
""",
    visibility = ["//visibility:public"],
)
