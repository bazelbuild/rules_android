# Python Support

The `rules_android` repo features several tools written in Python, so this
package has setup and support for the Python toolchain and dependencies.

## Pip Requirements

The tools used require some packages from PyPy, listed in the file
`requirements.in`. When this changes, the files `requirements_lock.txt` and
`vendored_py_requirements.bzl` (only used without bzlmod) must be updated.

### Lockfile

To regenerate the lockfile (used with and without bzlmod), run the following:

```sh
$ touch py_support/requirements_lock.txt
$ bazel run //py_support:requirements.update
$ bazel test //py_support:requirements_test
```

Make sure to commit the generated `requirements_lock.txt` file.

### Vendored Requirements

For non-bzlmod use, the pip requirements are vendored and checked into the
repository, so that users do not need to directly configure their own Python
toolchain containing the needed dependencies.

**NOTE:** Because `MODULE.bzl` handles loading the needed Python toolchains,
this step is not required.

To create the file, we need to first update the WORKSPACE to include the
toolchain, then query the external repository (to create the file), and finally
copy it into the `py_support` package.

Update `defs.bzl` by removing the `python_register_toolchains`, `pip_parse`, and
`pip_install_deps` targets.

Update `WORKSPACE` by adding the following to the end:

```py
load("@rules_python//python:repositories.bzl", "python_register_toolchains")

python_register_toolchains(
    name = "python3_11",
    python_version = "3.11",
)

load("@python3_11//:defs.bzl", "interpreter")
load("@rules_python//python:pip.bzl", "pip_parse")

pip_parse(
    name = "py_deps",
    python_interpreter_target = interpreter,
    requirements_lock = "//py_support:requirements_lock.txt",
)

load("@py_deps//:requirements.bzl", pip_install_deps = "install_deps")

pip_install_deps()
```

Then run the following commands:

```sh
$ bazel query --enable_bzlmod=false @py_deps//...
$ cp $(bazel info output_base)/external/py_deps/requirements.bzl py_support/vendored_py_requirements.bzl
```

Make sure to commit the updated `vendored_py_requirements.bzl`, but **DO NOT**
commit the updated WORKSPACE or defs.bzl.
