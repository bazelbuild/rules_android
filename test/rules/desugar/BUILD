load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load("@rules_bazel_integration_test//bazel_integration_test:defs.bzl", "script_test")
load("@rules_shell//shell:sh_library.bzl", "sh_library")

package(default_applicable_licenses = ["//:license"])

sh_library(
    name = "test_data",
    testonly = True,
    data = [
        "//:MODULE.bazel",
        "//rules:bzl",
    ],
)

[
    script_test(
        name = "desugar_worker_bazel_%s_test" % major,
        srcs = ["desugar_worker_test.sh"],
        bazel_binaries = bazel_binaries,
        bazel_version = version,
        deps = [
            ":test_data",
            "//test/bashunit",
            "@rules_shell//shell/runfiles",
        ],
    )
    for major, version in [
        ("9", "9.2.0"),
        ("10", "last_green"),
    ]
]

test_suite(
    name = "desugar_worker_tests",
    tests = [
        ":desugar_worker_bazel_10_test",
        ":desugar_worker_bazel_9_test",
    ],
)
