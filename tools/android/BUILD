load(":defs.bzl", "android_jar")

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
    name = "java8_legacy_dex",
    actual = "@bazel_tools//tools/android:java8_legacy_dex",
    visibility = ["//visibility:public"],
)

alias(
    name = "desugar_java8",
    actual = "@bazel_tools//tools/android:desugar_java8",
    visibility = ["//visibility:public"],
)

alias(
    name = "desugared_java8_legacy_apis",
    actual = "@bazel_tools//tools/android:desugared_java8_legacy_apis",
    visibility = ["//visibility:public"],
)

java_binary(
    name = "r8",
    main_class = "com.android.tools.r8.R8",
    visibility = ["//visibility:public"],
    runtime_deps = ["@android_gmaven_r8//jar"],
)

java_binary(
    name = "resource_shrinker",
    main_class = "com.android.build.shrinker.ResourceShrinkerCli",
    visibility = ["//visibility:public"],
    runtime_deps = ["@rules_android_maven//:com_android_tools_build_gradle"],
)
