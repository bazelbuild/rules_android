load(
    "//test/utils:lib.bzl",
    "asserts",
    "unittest",
)
load(
    ":custom_android_library.bzl",
    "CustomProvider",
)

def custom_android_library_test_impl(ctx):
    env = unittest.begin(ctx)

    # Assert that the custom provider exists
    asserts.true(env, CustomProvider in ctx.attr.lib)
    asserts.equals(env, ctx.attr.lib[CustomProvider].key, "test_key")

    return unittest.end(env)

custom_android_library_test = unittest.make(
    impl = custom_android_library_test_impl,
    attrs = {
        "lib": attr.label(providers = [CustomProvider]),
    },
)
