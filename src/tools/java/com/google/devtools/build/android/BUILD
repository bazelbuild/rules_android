# Actions for Android rules.

load("@rules_java//java:defs.bzl", "java_binary", "java_import", "java_library")
load("//tools/android:defs.bzl", "run_singlejar")

package(default_visibility = ["//visibility:public"])

# Used by //src/test/shell/bazel/android:android_integration_test
java_binary(
    name = "ResourceProcessorBusyBox",
    main_class = "com.google.devtools.build.android.ResourceProcessorBusyBox",
    runtime_deps = [
        ":android_builder_lib",
    ],
)

java_binary(
    name = "ZipFilterAction",
    # Memory consumption of SingleJar is about 250 bytes per entry in the output file. Unfortunately,
    # the JVM tends to kill the process with an OOM long before we're at the limit. In the most
    # recent example, 400 MB of memory was enough for about 500,000 entries.
    jvm_flags = ["-Xmx1600m"],
    main_class = "com.google.devtools.build.android.ZipFilterAction",
    visibility = ["//tools/android:__pkg__"],
    runtime_deps = [":android_builder_lib"],
)

run_singlejar(
    name = "zip_jar_gen",
    srcs = ["@android_tools//:all_android_tools_deploy.jar"],
    out = "zip.jar",
    include_prefixes = [
        "com/google/devtools/build/zip/",
    ],
)

java_import(
    name = "zip_jar",
    jars = [":zip_jar_gen"],
)

run_singlejar(
    name = "singlejar_jar_gen",
    srcs = ["@android_tools//:all_android_tools_deploy.jar"],
    out = "singlejar.jar",
    include_prefixes = [
        "com/google/devtools/build/singlejar/",
    ],
)

java_import(
    name = "singlejar_jar",
    jars = [":singlejar_jar_gen"],
)

run_singlejar(
    name = "databinding_exec_jar_gen",
    srcs = ["@android_tools//:all_android_tools_deploy.jar"],
    out = "databinding_exec.jar",
    include_prefixes = [
        "android/databinding/",
        "androidx/databinding/",
        "api-versions.xml",
        "com/android/tools/build/",
        "com/beust/jcommander/",
        "com/google/auto/common/",
        "com/google/common/base/",
        "com/google/common/collect/",
        "com/google/gson/",
        "com/squareup/javapoet/",
        "com/sun/istack/",
        "com/sun/xml/",
        "default.generated.config",
        "javax/activation/",
        "javax/xml/",
        "kotlin/",
        "org/antlr/v4/",
        "org/apache/commons/io/",
        "org/objectweb/asm",
        "org/mozilla/universalchardet/",
    ],
)

java_import(
    name = "databinding_exec_jar",
    jars = [":databinding_exec_jar_gen"],
)

run_singlejar(
    name = "kotlin_jar_gen",
    srcs = ["@android_tools//:all_android_tools_deploy.jar"],
    out = "kotlin.jar",
    include_prefixes = [
        "kotlin/",
    ],
)

java_import(
    name = "kotlin_jar",
    jars = [":kotlin.jar"],
)

java_library(
    name = "android_databinding_wrapper_lib",
    srcs = [
        "AndroidDataBindingWrapper.java",
        "ProcessXmlOptionsWrapper.java",
    ],
    deps = [
        ":databinding_exec_jar",
    ],
)

java_library(
    name = "android_builder_lib",
    srcs = glob(
        [
            "*.java",
            "xml/*.java",
            "aapt2/*.java",
        ],
        exclude = [
            "AndroidOptionsUtils.java",
            "DependencyInfo.java",
            "CompatShellQuotedParamsFileProcessor.java",
            "AndroidDataBindingWrapper.java",
            "ProcessXmlOptionsWrapper.java",
        ],
    ),
    javacopts = [
        "--add-exports=java.xml/com.sun.org.apache.xerces.internal.dom=ALL-UNNAMED",
    ],
    exports = [
        # Separated out to avoid a dependency cycle with resources/, but it logically belongs here.
        ":dependency_info",
    ],
    deps = [
        ":android_common_30_1_3",
        ":android_common_jar",
        ":android_databinding_wrapper_lib",
        ":android_options_utils",
        ":dependency_info",
        ":kotlin_jar",
        ":singlejar_jar",
        ":zip_jar",
        "//src/tools/java/com/google/devtools/build/android/junctions",
        "//src/tools/java/com/google/devtools/build/android/proto:resources_java_proto",
        "//src/tools/java/com/google/devtools/build/android/proto:serialize_format_java_pb",
        "//src/tools/java/com/google/devtools/build/android/resources",
        "//src/tools/java/com/google/devtools/build/android/ziputils:ziputils_lib",
        "//tools/android:autovalue",
        "@bazel_worker_java//:worker_protocol_java_proto",
        "@bazel_worker_java//src/main/java/com/google/devtools/build/lib/worker:work_request_handlers",
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_errorprone_error_prone_annotations",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:com_google_protobuf_protobuf_java",
        "@rules_android_maven//:org_gradle_gradle_core",
    ],
)

java_library(
    name = "dependency_info",
    srcs = ["DependencyInfo.java"],
    visibility = [":__subpackages__"],
    deps = [
        "//tools/android:autovalue",
    ],
)

run_singlejar(
    name = "android_common_jar_gen",
    srcs = ["@android_tools//:all_android_tools_deploy.jar"],
    out = "android_common_exec.jar",
    include_prefixes = [
        "com/google/wireless/",
        "com/android/",
    ],
)

java_import(
    name = "android_common_jar",
    jars = [
        ":android_common_jar_gen",
    ],
)

java_library(
    name = "android_common_30_1_3",
    runtime_deps = [
        ":android_common_jar",
        "@rules_android_maven//:com_android_tools_build_aapt2_proto",
        "@rules_android_maven//:org_ow2_asm_asm",
        "@rules_android_maven//:org_ow2_asm_asm_commons",
        "@rules_android_maven//:org_ow2_asm_asm_tree",
        "@rules_android_maven//:org_ow2_asm_asm_util",
    ],
)

java_library(
    name = "android_options_utils",
    srcs = [
        "AndroidOptionsUtils.java",
        "CompatShellQuotedParamsFilePreProcessor.java",
    ],
    visibility = [
        "//src/test/java/com/google/devtools/build/android:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/desugar/scan:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/dexer:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/idlclass:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/r8:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/ziputils:__pkg__",
    ],
    deps = [
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_guava_guava",
    ],
)
