# Configuration needed to manage python dependencies.
# This package is needed for Bazel support.

load("@rules_python//python:pip.bzl", "compile_pip_requirements")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:private"],
)

exports_files([
    "requirements_lock.txt",
    "vendored_py_requirements.bzl",
])

# This stanza calls a rule that generates targets for managing pip dependencies
# with pip-compile.
compile_pip_requirements(
    name = "requirements",
    requirements_in = "requirements.in",
    requirements_txt = "requirements_lock.txt",
)
