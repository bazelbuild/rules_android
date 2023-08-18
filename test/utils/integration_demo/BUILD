package(
    default_applicable_licenses = ["//:license"],
    default_visibility = [
        "//test:__subpackages__",
    ],
)

licenses(["notice"])

sh_test(
    name = "demo_test",
    srcs = ["demo_test.sh"],
    deps = [
        "//test/bashunit",
        "@bazel_tools//tools/bash/runfiles",
    ],
)
