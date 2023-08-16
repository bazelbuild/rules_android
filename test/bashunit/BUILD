load("@rules_python//python:py_test.bzl", "py_test")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = [
        "//test:__subpackages__",
    ],
)

licenses(["notice"])

exports_files(
    ["unittest.bash"],
)

sh_library(
    name = "bashunit",
    testonly = True,
    srcs = [
        "unittest.bash",
        "unittest_utils.sh",
    ],
)

# Test bashunit with python to avoid recursion.
py_test(
    name = "bashunit_test",
    size = "medium",
    srcs = ["unittest_test.py"],
    data = [
        ":bashunit",
        # This test relies on writing shell scripts that use bash runfiles
        # to load the actual copy of unittest.bash being tested.
        "@bazel_tools//tools/bash/runfiles",
    ],
    main = "unittest_test.py",
    python_version = "PY3",
    srcs_version = "PY3",
    tags = [
        "manual",  # TODO(b/266084774): Re-enable this.
        "no_windows",  # test runs bash scripts in a subprocess
    ],
)
