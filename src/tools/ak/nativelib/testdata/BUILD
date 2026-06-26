# Creates test data for testing the nativelib action.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src/tools/ak/nativelib:__subpackages__"],
)

licenses(["notice"])

genrule(
    name = "dummy_so",
    outs = ["dummy.so"],
    cmd = "touch $@",
)
