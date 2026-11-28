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

genquery(
    name = "desugar_globals_rules",
    expression = "set(//tools/android:desugar_globals //tools/android:desugar_globals_classes)",
    opts = ["--output=build"],
    scope = [
        "//tools/android:desugar_globals",
        "//tools/android:desugar_globals_classes",
    ],
)

sh_test(
    name = "desugar_globals_deterministic_test",
    size = "small",
    srcs = ["desugar_globals_deterministic_test.sh"],
    args = [
        "$(rootpath :desugar_globals_rules)",
    ],
    data = [":desugar_globals_rules"],
)
