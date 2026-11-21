"""Rules for importing the Android SDK from http archive.

Rule remote_android_sdk_repository imports an SDK and creates toolchain definitions for it.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_SDK_REPO_TEMPLATE = Label(":template.bzl")

_BUILD_TOOLS_DIR = "build-tools"
_PLATFORMS_DIR = "platforms"
_SYSTEM_IMAGES_DIR = "system-images"

_SDK_DIRS = {
    "build_tools": _BUILD_TOOLS_DIR,
    "cmdline_tools": "cmdline-tools",
    "emulator": "emulator",
    "ndk": "ndk",
    "platform_tools": "platform-tools",
    "platforms": _PLATFORMS_DIR,
}

def _remote_android_sdk_repository_impl(repo_ctx):
    for attr_name, output_dir in _SDK_DIRS.items():
        attr_value = struct(**getattr(repo_ctx.attr, attr_name))

        repo_ctx.download_and_extract(
            url = attr_value.url,
            sha256 = attr_value.sha256,
            output = output_dir + "/" + attr_value.add_prefix,
            stripPrefix = attr_value.strip_prefix,
        )

    repo_ctx.symlink(Label(":helper.bzl"), "helper.bzl")
    repo_ctx.template(
        "BUILD.bazel",
        _SDK_REPO_TEMPLATE,
        substitutions = {
            "__repository_name__": repo_ctx.name,
            "__build_tools_version__": repo_ctx.attr.build_tools_version,
            "__build_tools_directory__": repo_ctx.attr.build_tools_version,
            "__api_levels__": str(repo_ctx.attr.api_level),
            "__default_api_level__": str(repo_ctx.attr.api_level),
            "__system_image_dirs__": "",
            "__exec_compatible_with__": ",".join(["\"{}\"".format(platform) for platform in repo_ctx.attr.exec_compatible_with]),
        },
    )
    return None

_remote_android_sdk_repository = repository_rule(
    implementation = _remote_android_sdk_repository_impl,
    attrs = {
        "api_level": attr.int(default = 0),
        "build_tools_version": attr.string(),
        "build_tools": attr.string_dict(mandatory = True),
        "cmdline_tools": attr.string_dict(mandatory = True),
        "platforms": attr.string_dict(mandatory = True),
        "platform_tools": attr.string_dict(mandatory = True),
        "emulator": attr.string_dict(mandatory = True),
        "ndk": attr.string_dict(mandatory = True),
        "exec_compatible_with": attr.string_list(),
    },
)

# And here we define an extra repository androidsdk that contains the alias

def remote_android_sdk_repository(name, sdk):
    """Imports an Android SDK from a http archive and creates runtime toolchain definitions for it.

    Register the toolchains defined by this macro via `register_toolchains("@<name>//:all")`, where
    `<name>` is the value of the `name` parameter.

    Toolchain resolution is determined with exec_compatible_with parameter.

    Args:
      name: A unique name for this rule.
      sdk: Android SDK configuration.
    """
    _remote_android_sdk_repository(
        name = name,
        api_level = sdk["api_level"],
        build_tools_version = sdk["build_tools_version"],
        build_tools = sdk["build_tools"],
        cmdline_tools = sdk["cmdline_tools"],
        platforms = sdk["platforms"],
        platform_tools = sdk["platform_tools"],
        ndk = sdk["ndk"],
        emulator = sdk["emulator"],
        exec_compatible_with = sdk["exec_compatible_with"],
    )
    native.register_toolchains("@%s//:sdk-toolchain" % name)
    native.register_toolchains("@%s//:all" % name)
