exports_files([
    "data_binding_annotation_template.txt",
    "res_v3_dummy_AndroidManifest.xml",
    "res_v3_dummy_R.txt",
    "robolectric_properties_template.txt",
])

alias(
    name = "ResourceProcessorBusyBox",
    actual = "@bazel_tools//tools/android:busybox",
    visibility =  ["//visibility:public"],
)

alias(
    name = "current_java_runtime",
    actual = "@bazel_tools//tools/jdk:current_java_runtime",
    visibility = ["//visibility:public"],
)
