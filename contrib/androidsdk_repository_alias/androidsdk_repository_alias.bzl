"""androidsdk_repository_alias rule.

Shim rule to access the configured androidsdk for the current platform under a known name.
Usefule to be backwards compatible with current usages of @androidsdk//
"""

def _android_sdk_repository_alias_impl(repo_ctx):
    repo_ctx.symlink(Label(":rule.bzl.template"), "rule.bzl")
    repo_ctx.symlink(Label(":BUILD.bazel.template"), "BUILD.bazel")
    return None

androidsdk_repository_alias = repository_rule(
    implementation = _android_sdk_repository_alias_impl,
)
