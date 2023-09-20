# Creates test data for testing the rjar action.

package(default_visibility = ["//src/tools/ak/rjar:__subpackages__"])

licenses(["notice"])

genrule(
    name = "pkgs",
    outs = ["pkgs.txt"],
    cmd = "printf 'android.support.v7\ncom.google.android.samples.skeletonapp\ncom.google.android.package.test' > '$@'",
)

genrule(
    name = "R",
    srcs = ["//src/java/com/example/sampleapp:_migrated/lib.srcjar"],
    outs = ["R.java"],
    cmd = """
    unzip -p $(location //src/java/com/example/sampleapp:_migrated/lib.srcjar) com/example/sampleapp/R.java > '$@'
    sed -i -- '/public final class R/,$$!d' '$@'
    sed -i -- 's/@Deprecated//g' '$@'
    sed -i -- 's/ final / /g' '$@'
""",
)
