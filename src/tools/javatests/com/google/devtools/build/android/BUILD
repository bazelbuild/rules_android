load("@rules_java//java:defs.bzl", "java_library", "java_test")

filegroup(
    name = "srcs",
    srcs = glob(["**"]) + [
        "//src/tools/javatests/com/google/devtools/build/android/desugar:srcs",
        "//src/tools/javatests/com/google/devtools/build/android/dexer:srcs",
        "//src/tools/javatests/com/google/devtools/build/android/idlclass:srcs",
        "//src/tools/javatests/com/google/devtools/build/android/junctions:srcs",
        "//src/tools/javatests/com/google/devtools/build/android/r8:srcs",
        "//src/tools/javatests/com/google/devtools/build/android/resources:srcs",
        "//src/tools/javatests/com/google/devtools/build/android/testing/manifestmerge:srcs",
        "//src/tools/javatests/com/google/devtools/build/android/xml:srcs",
        "//src/tools/javatests/com/google/devtools/build/android/ziputils:srcs",
    ],
    visibility = ["//src:__pkg__"],
)

java_test(
    name = "AarGeneratorActionTest",
    size = "small",
    srcs = ["AarGeneratorActionTest.java"],
    deps = [
        ":guava",
        ":test_utils",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_common_30_1_3",
        "//src/tools/java/com/google/devtools/build/android:android_options_utils",
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "AndroidResourceOutputsTest",
    size = "small",
    srcs = ["AndroidResourceOutputsTest.java"],
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "AndroidManifestTest",
    size = "small",
    srcs = ["AndroidManifestTest.java"],
    deps = [
        ":guava",
        ":test_utils",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "RClassGeneratorActionTest",
    size = "small",
    srcs = ["RClassGeneratorActionTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "AaptCommandBuilderTest",
    size = "small",
    srcs = ["AaptCommandBuilderTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_common_30_1_3",
        "@rules_android_maven//:com_google_guava_guava_testlib",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "AndroidDataMergerTest",
    size = "small",
    srcs = ["AndroidDataMergerTest.java"],
    deps = [
        ":guava",
        ":test_utils",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_common_30_1_3",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "AndroidDataSerializerAndDeserializerTest",
    size = "small",
    srcs = ["AndroidDataSerializerAndDeserializerTest.java"],
    deps = [
        ":guava",
        ":test_utils",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "AndroidDataWriterTest",
    size = "small",
    srcs = ["AndroidDataWriterTest.java"],
    deps = [
        ":guava",
        ":test_utils",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_common_30_1_3",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_library(
    name = "test_options",
    srcs = ["TestOptions.java"],
    deps = [
        "@rules_android_maven//:com_beust_jcommander",
    ],
)

java_test(
    name = "AndroidOptionsUtilsTest",
    size = "small",
    srcs = ["AndroidOptionsUtilsTest.java"],
    deps = [
        ":test_options",
        "//src/tools/java/com/google/devtools/build/android:android_options_utils",
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "AndroidResourceClassWriterTest",
    size = "small",
    srcs = ["AndroidResourceClassWriterTest.java"],
    deps = [
        ":guava",
        ":test_utils",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android/resources",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "ConvertersTest",
    size = "small",
    srcs = ["ConvertersTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "DataResourceXmlTest",
    size = "small",
    srcs = ["DataResourceXmlTest.java"],
    deps = [
        ":guava",
        ":test_utils",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_common_30_1_3",
        "//src/tools/java/com/google/devtools/build/android/resources",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "DataSourceTest",
    size = "small",
    srcs = ["DataSourceTest.java"],
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "DataValueFileTest",
    size = "small",
    srcs = ["DataValueFileTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android/resources",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "DensitySpecificManifestProcessorTest",
    size = "small",
    srcs = ["DensitySpecificManifestProcessorTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "DensitySpecificResourceFilterTest",
    size = "small",
    srcs = ["DensitySpecificResourceFilterTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "DependencyAndroidDataTest",
    size = "small",
    srcs = ["DependencyAndroidDataTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "ManifestMergerActionTest",
    size = "small",
    srcs = ["ManifestMergerActionTest.java"],
    data = [
        "//src/tools/javatests/com/google/devtools/build/android/testing/manifestmerge:test_data",
    ],
    deps = [
        ":guava",
        ":test_utils",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "ParsedAndroidDataTest",
    size = "small",
    srcs = ["ParsedAndroidDataTest.java"],
    deps = [
        ":guava",
        ":test_utils",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_common_30_1_3",
        "//src/tools/java/com/google/devtools/build/android/resources",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "PlaceholderRTxtWriterTest",
    size = "small",
    srcs = ["PlaceholderRTxtWriterTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_common_30_1_3",
        "//src/tools/java/com/google/devtools/build/android/resources",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "SerializedAndroidDataTest",
    size = "small",
    srcs = ["SerializedAndroidDataTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "UnvalidatedAndroidDataTest",
    size = "small",
    srcs = ["UnvalidatedAndroidDataTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "UnvalidatedAndroidDirectoriesTest",
    size = "small",
    srcs = ["UnvalidatedAndroidDirectoriesTest.java"],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_jimfs_jimfs",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_test(
    name = "ZipFilterActionTest",
    size = "small",
    srcs = ["ZipFilterActionTest.java"],
    data = [
        "//tools/jdk:singlejar",
    ],
    jvm_flags = [
        "-Drunfiles.path=$$TEST_SRCDIR",
        # NOTE: Singlejar technically comes from an "external" source, so its repo mapping is under "_main/external".
        "-Dsinglejar.path=$$TEST_WORKSPACE/$(execpath //tools/jdk:singlejar)",
    ],
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)

java_library(
    name = "error_prone_annotations",
    testonly = 1,
    exports = [
        "@rules_android_maven//:com_google_errorprone_error_prone_annotations",
    ],
)

java_library(
    name = "guava",
    testonly = 1,
    exports = [
        ":error_prone_annotations",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_guava_guava",
    ],
)

java_library(
    name = "test_utils",
    testonly = 1,
    srcs = glob(
        ["*.java"],
        exclude = ["*Test.java"],
    ),
    deps = [
        ":guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_common_30_1_3",
        "//src/tools/java/com/google/devtools/build/android/resources",
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_errorprone_error_prone_annotations",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:com_google_truth_truth",
    ],
)
