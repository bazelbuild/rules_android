# Protos of the Actions for Android rules.

load("@com_google_protobuf//bazel:java_proto_library.bzl", "java_proto_library")
load("@rules_proto//proto:defs.bzl", "proto_library")

package(default_visibility = ["//visibility:public"])

java_proto_library(
    name = "serialize_format_java_pb",
    deps = [":serialize_format_proto"],
)

proto_library(
    name = "serialize_format_proto",
    srcs = ["serialize_format.proto"],
)

java_proto_library(
    name = "resources_java_proto",
    deps = [":resources_proto"],
)

[
    genrule(
        name = proto + "_proto_file",
        srcs = ["@maven//:com_android_tools_build_aapt2_proto"],
        outs = [proto + ".proto"],
        cmd = "unzip -q $< " + proto + ".proto && " +
              "sed 's/import \\\"/import \\\"src\\/tools\\/java\\/com\\/google\\/devtools\\/build\\/android\\/proto\\//' " + proto + ".proto > $@",
    )
    for proto in [
        "Configuration",
        "Resources",
        "ResourcesInternal",
    ]
]

proto_library(
    name = "resources_proto",
    srcs = [
        ":Configuration.proto",
        ":Resources.proto",
        ":ResourcesInternal.proto",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
)
