# Description:
#   Tests for the AndroidRevisionInfo provider.

load(":test.bzl", "android_revision_comparision_test", "android_revision_test")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

# Test revision string parsing.
# buildifier: leave-alone
android_revision_test(
    name = "version_1.2.3",
    input = "1.2.3",
    expected_major = 1,
    expected_minor = 2,
    expected_micro = 3,
    expected_version = "1.2.3",
    expected_dir = "1.2.3",
)

# buildifier: leave-alone
android_revision_test(
    name = "micro_missing",
    input = "1.2",
    expected_major = 1,
    expected_minor = 2,
    expected_micro = 0,
    expected_version = "1.2",
    expected_dir = "1.2",
)

# buildifier: leave-alone
android_revision_test(
    name = "minor_missing",
    input = "1",
    expected_major = 1,
    expected_minor = 0,
    expected_micro = 0,
    expected_version = "1",
    expected_dir = "1",
)

# Test revision comparisions.
VERSIONS = [
    ("2.0.0", "1.0.0"),
    ("12.0.0", "11.0.0"),
    ("1.1.0", "1.0.0"),
    ("1.0.1", "1.0.0"),
    ("1.1.1", "1.0.1"),
    ("2", "1"),
    ("2.1", "2"),
    ("2", "1.0"),
    # TODO(katre): Re-add when previews are supported.
    #("1.1.0-rc1", "1.0.0-rc1"),
    #("1.1.0-alpha1", "1.0.0-rc1"),
    #("1.0.0", "1.0.0-rc1"),
    #("1.0.0", "1.0.0-rc2"),
    #("1.0.0", "1.0.0-alpha1"),
    #("1.0.0", "1.0.0-alpha2"),
    #("1.0.0", "1.0.0-beta1"),
    #("1.0.0", "1.0.0-beta2"),
    #("1.0.0-rc1", "1.0.0-beta1"),
    #("1.0.0-beta1", "1.0.0-alpha1"),
    #("1.0.0-beta1", "1.0.0-alpha2"),
    #("1.0.0-rc2", "1.0.0-rc1"),
    #("1.0.0-beta2", "1.0.0-beta1"),
    #("1.0.0-alpha2", "1.0.0-alpha1"),
    #("1 rc1", "1 beta1"),
]

[
    android_revision_comparision_test(
        name = "compare_%s_%s" % (higher, lower),
        higher = higher,
        lower = lower,
    )
    for (higher, lower) in VERSIONS
]

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//visibility:private"],
)
