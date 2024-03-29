load(":defs.bzl", "android_jar")

config_setting(
    name = "minimal_desugaring",
    values = {
        "define": "java8_library_desugaring=minimal",
    }
)

config_setting(
    name = "full_desugaring",
    values = {
        "define": "java8_library_desugaring=full",
    }
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

alias(
    name = "debug_keystore",
    actual = "@bazel_tools//tools/android:debug_keystore",
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
        "@bazel_tools//src/tools/android/java/com/google/devtools/build/android:all_android_tools",
    ],
)

alias(
    name = "zip",
    actual = "//toolchains/android:zip",
    visibility = ["//visibility:public"],
)

genrule(
    name = "full_desugar_jdk_libs_config_json",
    outs = ["full_desugar_jdk_libs_config.json"],
    srcs = [
        "@rules_android_maven//:com_android_tools_desugar_jdk_libs_configuration_nio",
    ],
    cmd = "unzip -q -c " +
          "$(location @rules_android_maven//:com_android_tools_desugar_jdk_libs_configuration_nio) " +
          "META-INF/desugar/d8/desugar.json > $@",
)

genrule(
    name = "minimal_desugar_jdk_libs_config_json",
    outs = ["minimal_desugar_jdk_libs_config.json"],
    srcs = [
        "@rules_android_maven//:com_android_tools_desugar_jdk_libs_configuration_minimal",
    ],
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
    outs = ["minify_desugar_jdk_libs.pgcfg"],
    srcs = [
        "//src/tools/extract_desugar_pgcfg_flags",
        ":desugar_jdk_libs_json",
    ],
    cmd = "$(location //src/tools/extract_desugar_pgcfg_flags) --input_json $(location :desugar_jdk_libs_json) --output_file $@"
)

genrule(
    name = "build_java8_legacy_dex_params",
    outs = ["build_java8_legacy_dex_params.txt"],
    cmd = "echo -n --min-api 19 > $@",
    visibility = ["//visibility:private"],
)

genrule(
    name = "desugared_jdk_libs_from_maven_jar",
    outs = ["desugared_jdk_libs_from_maven.jar"],
    srcs = select({
        "full_desugaring": ["@rules_android_maven//:com_android_tools_desugar_jdk_libs_nio"],
        "minimal_desugaring": ["@rules_android_maven//:com_android_tools_desugar_jdk_libs_minimal"],
        "//conditions:default": ["@rules_android_maven//:com_android_tools_desugar_jdk_libs_nio"],
    }),
    cmd = "cp $< $@",
)

genrule(
    name = "desugared_jdk_libs_jar",
    outs = ["desugared_jdk_libs.jar"],
    srcs = [":desugared_jdk_libs_from_maven.jar", ":full_desugar_jdk_libs_config_json"],
    tools = [":desugar_java8"],
    cmd = "$(location :desugar_java8) " +
          "--desugared_lib_config $(location :full_desugar_jdk_libs_config_json) " +
          "--input=$(location :desugared_jdk_libs_from_maven.jar) --output=$@",
)

sh_binary(
    name = "build_java8_legacy_dex",
    srcs = ["build_java8_legacy_dex.sh"],
    data = [
        "build_java8_legacy_dex_params",
        ":minify_desugar_jdk_libs.pgcfg",
        ":desugared_jdk_libs_jar",
        ":d8",
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
        "@bazel_tools//src/tools/android/java/com/google/devtools/build/android/r8:desugar",
        ":full_desugar_jdk_libs_config_json",
        "@bazel_tools//tools/bash/runfiles",
    ],
    visibility = ["//visibility:public"],
)

alias(
    name = "desugared_java8_legacy_apis",
    actual = ":gen_fail",  # TODO(#122): Fix library desugaring
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
    name = "dexbuilder",
    actual = "@bazel_tools//tools/android:dexbuilder",
    visibility = ["//visibility:public"],
)

alias(
    name = "dexmerger",
    actual = "@bazel_tools//tools/android:dexmerger",
    visibility = ["//visibility:public"],
)
