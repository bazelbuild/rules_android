# Defines targets for the apksigner build tool.
load("@rules_java//java:defs.bzl", "java_binary", "java_library", "java_test")

java_binary(
    name = "apksigner",
    srcs = glob(
        ["**/*.java"],
        exclude = [
            "**/test/**",
            "**/*Test.java",
        ],
    ),
    main_class = "com.android.apksigner.ApkSignerTool",
    visibility = ["//visibility:public"],
    deps = [
        "@rules_android_maven//:org_bouncycastle_bcprov_jdk18on",
        "@rules_android_maven//:org_conscrypt_conscrypt_openjdk_uber",
    ],
)
