load("//rules:rules.bzl", "aar_import")
load(":test.bzl", "min_sdk_bump_skipped_test", "min_sdk_bumped_test")

# The tests only analyze :lib, so the AAR can be empty. :lib is tagged manual so that
# `bazel build //test/...` does not run its actions.
genrule(
    name = "gen_empty_aar",
    outs = ["empty.aar"],
    cmd = "touch $@",
)

aar_import(
    name = "lib",
    aar = "empty.aar",
    package = "com.example.lib",
    tags = ["manual"],
)

min_sdk_bumped_test(
    name = "min_sdk_bumped_test",
    target_under_test = ":lib",
)

min_sdk_bump_skipped_test(
    name = "min_sdk_bump_skipped_test",
    target_under_test = ":lib",
)
