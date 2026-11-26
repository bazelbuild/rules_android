load("@rules_java//java:java_library.bzl", "java_library")
load(":test.bzl", "classpath_test")

genrule(
    name = "gen_dep_java",
    outs = ["Dep.java"],
    cmd = "echo 'package com.example; public class Dep {}' > $@",
)

genrule(
    name = "gen_lib_java",
    outs = ["Lib.java"],
    cmd = "echo 'package com.example; public class Lib { Dep dep; }' > $@",
)

java_library(
    name = "dep",
    srcs = ["Dep.java"],
)

java_library(
    name = "lib",
    srcs = ["Lib.java"],
    deps = [":dep"],
)

classpath_test(
    name = "classpath_test",
    dep = ":dep",
    target_under_test = ":lib",
)
