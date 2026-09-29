load("@rules_shell//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "build_java8_legacy_dex_test",
    size = "small",
    srcs = ["build_java8_legacy_dex_test.sh"],
    args = [
        "$(rlocationpath //tools/android:build_java8_legacy_dex.sh)",
    ],
    data = [
        "//tools/android:build_java8_legacy_dex.sh",
    ],
    deps = ["@rules_shell//shell/runfiles"],
)
