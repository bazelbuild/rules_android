package(default_applicable_licenses = ["//:license"])

licenses(["notice"])

genrule(
    name = "generated_assets",
    srcs = [],
    outs = ["generated_data.txt"],
    cmd = "echo \"generated data\" > \"$@\"",
    visibility = ["//test/rules/resources:__subpackages__"],
)

genrule(
    name = "generated_assets_with_dir",
    srcs = [],
    outs = ["data/generated_data.txt"],
    cmd = "echo \"generated data in dir\" > \"$@\"",
    visibility = ["//test/rules/resources:__subpackages__"],
)
