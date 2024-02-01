load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_library.bzl", "py_library")
load("@rules_python//python:py_test.bzl", "py_test")

# Description:
#   Package for tool to validate the android manifest xml file.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

py_library(
    name = "validate_manifest_lib",
    srcs = ["validate_manifest.py"],
    srcs_version = "PY3",
    deps = ["@bazel_tools//third_party/py/abseil"],
)

py_test(
    name = "validate_manifest_test",
    srcs = ["validate_manifest_test.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    deps = [
        ":validate_manifest_lib",
    ],
)

py_binary(
    name = "validate_manifest",
    srcs = ["validate_manifest.py"],
    python_version = "PY3",
    visibility = ["//visibility:public"],
    deps = [
        ":validate_manifest_lib",
    ],
)
