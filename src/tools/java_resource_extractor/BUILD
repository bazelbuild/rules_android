# Description:
#   Tool to extract Java resources for packaging in an Android binary.

load("@rules_python//python:defs.bzl", "py_binary")

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//:__pkg__"],
)

py_binary(
    name = "resource_extractor",
    srcs = ["resource_extractor.py"],
    python_version = "PY3",
    visibility = ["//visibility:public"],
)
