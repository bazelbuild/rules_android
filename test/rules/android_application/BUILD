load("//rules:rules.bzl", "android_application")
load(":test.bzl", "key_rotation_test")

genrule(
    name = "gen_key1",
    srcs = ["key1.keystore"],
    outs = ["gen/key1.keystore"],
    cmd = "cp $< $@",
)

android_application(
    name = "rotated_app",
    bundle_config_file = "bundle_config.pb.json",
    debug_signing_keys = [
        ":gen_key1",
        "key2.keystore",
    ],
    debug_signing_lineage_file = "lineage.bin",
    deps = [],
    manifest = "AndroidManifest.xml",
    manifest_values = {"applicationId": "com.rotation"},
    tags = ["manual"],
)

key_rotation_test(
    name = "key_rotation_test",
    target_under_test = ":rotated_app",
)
