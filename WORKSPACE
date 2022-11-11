workspace(name = "build_bazel_rules_android")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

maybe(
    http_archive,
    name = "remote_java_tools_for_rules_android",
    sha256 = "8fb4d3138bd92a9d3324dae29c9f70d91ca2db18cd0bf1997446eed4657d19b3",
    urls = [
            "https://mirror.bazel.build/bazel_java_tools/releases/java/v11.8/java_tools-v11.8.zip",
            "https://github.com/bazelbuild/java_tools/releases/download/java_v11.8/java_tools-v11.8.zip",
    ],
)

maybe(
    http_archive,
    name = "com_google_protobuf",
    sha256 = "87407cd28e7a9c95d9f61a098a53cf031109d451a7763e7dd1253abf8b4df422",
    strip_prefix = "protobuf-3.19.1",
    urls = ["https://github.com/protocolbuffers/protobuf/archive/v3.19.1.tar.gz"],
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")
protobuf_deps()

maybe(
    http_archive,
    name = "rules_jvm_external",
    strip_prefix = "rules_jvm_external-fa73b1a8e4846cee88240d0019b8f80d39feb1c3",
    sha256 = "7e13e48b50f9505e8a99cc5a16c557cbe826e9b68d733050cd1e318d69f94bb5",
    url = "https://github.com/bazelbuild/rules_jvm_external/archive/fa73b1a8e4846cee88240d0019b8f80d39feb1c3.zip",
)

load("defs.bzl", "rules_android_workspace")

maybe(
    android_sdk_repository,
    name = "androidsdk",
)

maybe(
    android_ndk_repository,
    name = "androidndk",
)

maybe(
    http_archive,
    name = "bazel_skylib",
    sha256 = "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
    urls = [
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
    ],
)
register_toolchains("//toolchains/android:all")
register_toolchains("//toolchains/android_sdk:all")
register_toolchains("//toolchains/emulator:all")

maybe(
    http_archive,
    name = "io_bazel_rules_go",
    sha256 = "16e9fca53ed6bd4ff4ad76facc9b7b651a89db1689a2877d6fd7b82aa824e366",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.34.0/rules_go-v0.34.0.zip",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.34.0/rules_go-v0.34.0.zip",
    ],
)

maybe(
    http_archive,
    name = "bazel_gazelle",
    sha256 = "5982e5463f171da99e3bdaeff8c0f48283a7a5f396ec5282910b9e8a49c0dd7e",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.25.0/bazel-gazelle-v0.25.0.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.25.0/bazel-gazelle-v0.25.0.tar.gz",
    ],
)

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")
go_rules_dependencies()

go_register_toolchains(version = "1.18.3")

gazelle_dependencies()
# gazelle:repository go_repository name=org_golang_x_xerrors importpath=golang.org/x/xerrors

go_repository(
    name = "org_golang_google_protobuf",
    importpath = "google.golang.org/protobuf",
    sum = "h1:d0NfwRgPtno5B1Wa6L2DAG+KivqkdutMf1UhdNx175w=",
    version = "v1.28.1",
)

go_repository(
    name = "com_github_google_go_cmp",
    importpath = "github.com/google/go-cmp",
    sum = "h1:O2Tfq5qg4qc4AmwVlvv0oLiVAGB7enBSJ2x2DqQFi38=",
    version = "v0.5.9",
)

go_repository(
  name = "org_golang_x_sync",
  importpath = "golang.org/x/sync",
  sum = "h1:5KslGYwFpkhGh+Q16bwMP3cOontH8FOep7tGV86Y7SQ=",
  version = "v0.0.0-20210220032951-036812b2e83c",
)

rules_android_workspace()

