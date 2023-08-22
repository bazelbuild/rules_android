load("@rules_python//python:py_test.bzl", "py_test")

py_test(
    name = "r8_integration_test",
    srcs = ["r8_integration_test.py"],
    data = [
        "//test/rules/android_binary_internal/r8_integration/java/com/basicapp:basic_app_R8_no_shrink",
        "//test/rules/android_binary_internal/r8_integration/java/com/basicapp:basic_app_R8_shrink",
        "//test/rules/android_binary_internal/r8_integration/java/com/basicapp:basic_app_no_R8",
        "@androidsdk-supplemental//:dexdump",
    ],
)
