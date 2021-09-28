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
