load("@rules_java//java:defs.bzl", "java_import", "java_library", "java_test")

licenses(["notice"])

package(
    default_applicable_licenses = ["//:license"],
    default_testonly = 1,
)

java_test(
    name = "DesugarBasicTest",
    size = "small",
    srcs = [
        "DesugarBasicTest.java",
        "DesugarInfoCollector.java",
    ] + glob(["basic/*.java"]),
    data = [
        ":testdata_basic",
        ":testdata_basic_desugared",
        ":testdata_basic_desugared_classpath",
        ":testdata_basic_desugared_classpath_with_dependency_metadata",
        ":testdata_basic_desugared_with_dependency_metadata",
        ":testdata_basic_desugared_with_dependency_metadata_missing_interface",
        ":testdata_basic_double_desugared_with_dependency_metadata",
    ],
    jvm_flags = [
        "-DDesugarBasicTest.testdata_basic=$(location :testdata_basic)",
        "-DDesugarBasicTest.testdata_basic_desugared=$(location :testdata_basic_desugared)",
        "-DDesugarBasicTest.testdata_basic_desugared_classpath=$(location :testdata_basic_desugared_classpath)",
        "-DDesugarBasicTest.testdata_basic_desugared_with_dependency_metadata=$(location :testdata_basic_desugared_with_dependency_metadata)",
        "-DDesugarBasicTest.testdata_basic_double_desugared_with_dependency_metadata=$(location :testdata_basic_double_desugared_with_dependency_metadata)",
        "-DDesugarBasicTest.testdata_basic_desugared_classpath_with_dependency_metadata=$(location :testdata_basic_desugared_classpath_with_dependency_metadata)",
        "-DDesugarBasicTest.testdata_basic_desugared_with_dependency_metadata_missing_interface=$(location :testdata_basic_desugared_with_dependency_metadata_missing_interface)",
    ],
    deps = [
        "//src/tools/java/com/google/devtools/build/android/r8",
        "//third_party/bazel/src/main/protobuf:desugar_deps_java_proto",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
        "@rules_android_maven//:org_ow2_asm_asm",
    ],
)

java_library(
    name = "testdata_basic",
    srcs = glob(
        ["basic/*.java"],
    ),
)

java_library(
    name = "testdata_basic_interfaces",
    srcs = [
        "basic/I.java",
        "basic/J.java",
        "basic/K.java",
    ],
)

java_library(
    name = "testdata_basic_classes",
    srcs = [
        "basic/A.java",
        "basic/B.java",
        "basic/C.java",
        "basic/TestClass.java",
    ],
    deps = [
        ":testdata_basic_interfaces",
    ],
)

java_library(
    name = "testdata_basic_just_k",
    srcs = ["basic/K.java"],
)

java_library(
    name = "testdata_basic_missing_interface",
    srcs = glob(
        ["basic/*.java"],
        exclude = ["basic/K.java"],
    ),
    deps = [
        ":testdata_basic_just_k",
    ],
)

genrule(
    name = "desugar_testdata_basic",
    srcs = [
        ":testdata_basic",
        "//tools/android:bootclasspath",
    ],
    outs = ["testdata_basic_desugared.jar"],
    cmd = "$(location //src/tools/java/com/google/devtools/build/android/r8:desugar) " +
          "-i $(location :testdata_basic) -o $@ " +
          "--bootclasspath_entry $(location //tools/android:bootclasspath)",
    tools = ["//src/tools/java/com/google/devtools/build/android/r8:desugar"],
)

java_import(
    name = "testdata_basic_desugared",
    jars = ["testdata_basic_desugared.jar"],
)

genrule(
    name = "desugar_testdata_basic_classpath",
    srcs = [
        ":testdata_basic_interfaces",
        ":testdata_basic_classes",
        "//tools/android:bootclasspath",
    ],
    outs = ["testdata_basic_desugared_classpath.jar"],
    cmd = "$(location //src/tools/java/com/google/devtools/build/android/r8:desugar) " +
          "--classpath_entry $(location :testdata_basic_interfaces) " +
          "-i $(location :testdata_basic_classes) -o $@ " +
          "--bootclasspath_entry $(location //tools/android:bootclasspath)",
    tools = ["//src/tools/java/com/google/devtools/build/android/r8:desugar"],
)

java_import(
    name = "testdata_basic_desugared_classpath",
    jars = ["testdata_basic_desugared_classpath.jar"],
    tags = [
        "incomplete-deps",  # remove this suppression and add any missing deps, see internal java_import deps checking doc
    ],
)

genrule(
    name = "desugar_testdata_basic_with_dependency_metadata",
    srcs = [
        ":testdata_basic",
        "//tools/android:bootclasspath",
    ],
    outs = ["testdata_basic_desugared_with_dependency_metadata.jar"],
    cmd = "$(location //src/tools/java/com/google/devtools/build/android/r8:desugar) " +
          "-i $(location :testdata_basic) -o $@ " +
          "--bootclasspath_entry $(location //tools/android:bootclasspath) " +
          "--emit_dependency_metadata_as_needed",
    tools = ["//src/tools/java/com/google/devtools/build/android/r8:desugar"],
)

java_import(
    name = "testdata_basic_desugared_with_dependency_metadata",
    jars = ["testdata_basic_desugared_with_dependency_metadata.jar"],
)

# We should not output dependency metadata on the second run since we don't need to desugar anything
genrule(
    name = "double_desugar_testdata_basic_with_dependency_metadata",
    srcs = [
        ":testdata_basic_desugared",
        "//tools/android:bootclasspath",
    ],
    outs = ["testdata_basic_double_desugared_with_dependency_metadata.jar"],
    cmd = "$(location //src/tools/java/com/google/devtools/build/android/r8:desugar) " +
          "-i $(location :testdata_basic_desugared) -o $@ " +
          "--bootclasspath_entry $(location //tools/android:bootclasspath) " +
          "--emit_dependency_metadata_as_needed",
    tools = ["//src/tools/java/com/google/devtools/build/android/r8:desugar"],
)

java_import(
    name = "testdata_basic_double_desugared_with_dependency_metadata",
    jars = ["testdata_basic_double_desugared_with_dependency_metadata.jar"],
)

genrule(
    name = "desugar_testdata_basic_classpath_with_dependency_metadata",
    srcs = [
        ":testdata_basic_interfaces",
        ":testdata_basic_classes",
        "//tools/android:bootclasspath",
    ],
    outs = ["testdata_basic_desugared_classpath_with_dependency_metadata.jar"],
    cmd = "$(location //src/tools/java/com/google/devtools/build/android/r8:desugar) " +
          "--classpath_entry $(location :testdata_basic_interfaces) " +
          "-i $(location :testdata_basic_classes) -o $@ " +
          "--bootclasspath_entry $(location //tools/android:bootclasspath) " +
          "--emit_dependency_metadata_as_needed",
    tools = ["//src/tools/java/com/google/devtools/build/android/r8:desugar"],
)

java_import(
    name = "testdata_basic_desugared_classpath_with_dependency_metadata",
    jars = ["testdata_basic_desugared_classpath_with_dependency_metadata.jar"],
    tags = [
        "incomplete-deps",  # remove this suppression and add any missing deps, see internal java_import deps checking doc
    ],
)

genrule(
    name = "desugar_testdata_basic_with_dependency_metadata_missing_interface",
    srcs = [
        ":testdata_basic_missing_interface",
        "//tools/android:bootclasspath",
    ],
    outs = ["testdata_basic_desugared_with_dependency_metadata_missing_interface.jar"],
    cmd = "$(location //src/tools/java/com/google/devtools/build/android/r8:desugar) " +
          "-i $(location :testdata_basic_missing_interface) -o $@ " +
          "--bootclasspath_entry $(location //tools/android:bootclasspath) " +
          "--emit_dependency_metadata_as_needed",
    tools = ["//src/tools/java/com/google/devtools/build/android/r8:desugar"],
)

java_import(
    name = "testdata_basic_desugared_with_dependency_metadata_missing_interface",
    jars = ["testdata_basic_desugared_with_dependency_metadata_missing_interface.jar"],
    tags = [
        "incomplete-deps",  # remove this suppression and add any missing deps, see internal java_import deps checking doc
    ],
)
