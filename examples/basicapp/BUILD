filegroup(
    name = "all_files",
    srcs = glob(["*"]) + [
        "//java/com/basicapp:all_files",
    ],
)

genrule(
    name = "examples_basicapp_all_files_tar",
    srcs = [":all_files"],
    outs = ["examples_basicapp_all_files.tar"],
    cmd = "tar chf $@ $(locations :all_files) --transform 's,^,examples/basicapp/,'",
)