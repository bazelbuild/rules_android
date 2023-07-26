load("@rules_python//python:defs.bzl", "py_test")

exports_files([
    #"integration_test_setup.sh",
    "unittest.bash",
])

sh_library(
    name = "bashunit",
    testonly = True,
    srcs = [
        "unittest.bash",
        "unittest_utils.sh",
    ],
    visibility = ["//visibility:public"],
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
    tags = [
        "no_windows",  # test runs bash scripts in a subprocess
    ],
)
