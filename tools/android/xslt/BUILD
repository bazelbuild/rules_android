load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

exports_files(["add_g3itr.xslt"])

sh_binary(
    name = "xslt",
    srcs = ["xslt.sh"],
    visibility = ["//visibility:public"],
)
