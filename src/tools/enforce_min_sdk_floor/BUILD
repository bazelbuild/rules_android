load("@py_deps//:requirements.bzl", "requirement")
load("@rules_python//python:defs.bzl", "py_binary", "py_test")

# Description:
#   Package for tool to enforce min SDK floor on AndroidManifests

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

py_binary(
    name = "enforce_min_sdk_floor",
    srcs = ["enforce_min_sdk_floor.py"],
    deps = [
        "@bazel_tools//third_party/py/abseil",
        requirement("lxml"),
    ],
)

py_test(
    name = "enforce_min_sdk_floor_test",
    srcs = ["enforce_min_sdk_floor_test.py"],
    deps = [
        ":enforce_min_sdk_floor",
    ],
)
