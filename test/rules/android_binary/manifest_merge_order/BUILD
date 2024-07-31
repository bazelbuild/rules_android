load("@rules_python//python:py_test.bzl", "py_test")
load(":defs.bzl", "manifest_merge_split")

py_test(
    name = "manifest_merge_order_test",
    srcs = ["manifest_merge_order_test.py"],
    args = [
        "$(location @androidsdk//:aapt2_binary)",
        "$(locations :basic_app_manifest_merge_order)",
    ],
    data = [
        ":basic_app_manifest_merge_order",
        "@androidsdk//:aapt2_binary",
    ],
)

manifest_merge_split(
    name = "basic_app_manifest_merge_order",
    binary = "//test/rules/android_binary/manifest_merge_order/java/com/basicapp:basic_app",
)
