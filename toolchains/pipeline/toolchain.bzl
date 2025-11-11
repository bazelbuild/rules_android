load(
    "//rules/android_binary:impl.bzl",
    binary_pipeline = "PROCESSING_PIPELINE",
)
load(
    "//rules/android_library:impl.bzl",
    library_pipeline = "PROCESSING_PIPELINE",
)

def _impl(ctx):
    return [
        platform_common.ToolchainInfo(
            library = library_pipeline,
            binary = binary_pipeline,
        ),
    ]

android_toolchain = rule(
    implementation = _impl,
    attrs = {},
)
