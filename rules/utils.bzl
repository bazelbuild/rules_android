# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Utilities for the Android rules."""

load(":providers.bzl", "FailureInfo")

_CUU = "\033[A"
_EL = "\033[K"
_DEFAULT = "\033[0m"
_BOLD = "\033[1m"
_RED = "\033[31m"
_GREEN = "\033[32m"
_MAGENTA = "\033[35m"
_ERASE_PREV_LINE = "\n" + _CUU + _EL

_INFO = _ERASE_PREV_LINE + _GREEN + "INFO: " + _DEFAULT + "%s"
_WARNING = _ERASE_PREV_LINE + _MAGENTA + "WARNING: " + _DEFAULT + "%s"
_ERROR = _ERASE_PREV_LINE + _BOLD + _RED + "ERROR: " + _DEFAULT + "%s"

_WORD_CHARS = {
    "A": True,
    "B": True,
    "C": True,
    "D": True,
    "E": True,
    "F": True,
    "G": True,
    "H": True,
    "I": True,
    "J": True,
    "K": True,
    "L": True,
    "M": True,
    "N": True,
    "O": True,
    "P": True,
    "Q": True,
    "R": True,
    "S": True,
    "T": True,
    "U": True,
    "V": True,
    "W": True,
    "X": True,
    "Y": True,
    "Z": True,
    "a": True,
    "b": True,
    "c": True,
    "d": True,
    "e": True,
    "f": True,
    "g": True,
    "h": True,
    "i": True,
    "j": True,
    "k": True,
    "l": True,
    "m": True,
    "n": True,
    "o": True,
    "p": True,
    "q": True,
    "r": True,
    "s": True,
    "t": True,
    "u": True,
    "v": True,
    "w": True,
    "x": True,
    "y": True,
    "z": True,
    "0": True,
    "1": True,
    "2": True,
    "3": True,
    "4": True,
    "5": True,
    "6": True,
    "7": True,
    "8": True,
    "9": True,
    "_": True,
}

_HEX_CHAR = {
    0x0: "0",
    0x1: "1",
    0x2: "2",
    0x3: "3",
    0x4: "4",
    0x5: "5",
    0x6: "6",
    0x7: "7",
    0x8: "8",
    0x9: "9",
    0xA: "A",
    0xB: "B",
    0xC: "C",
    0xD: "D",
    0xE: "E",
    0xF: "F",
}

_JAVA_RESERVED = {
    "abstract": True,
    "assert": True,
    "boolean": True,
    "break": True,
    "byte": True,
    "case": True,
    "catch": True,
    "char": True,
    "class": True,
    "const": True,
    "continue": True,
    "default": True,
    "do": True,
    "double": True,
    "else": True,
    "enum": True,
    "extends": True,
    "final": True,
    "finally": True,
    "float": True,
    "for": True,
    "goto": True,
    "if": True,
    "implements": True,
    "import": True,
    "instanceof": True,
    "int": True,
    "interface": True,
    "long": True,
    "native": True,
    "new": True,
    "package": True,
    "private": True,
    "protected": True,
    "public": True,
    "return": True,
    "short": True,
    "static": True,
    "strictfp": True,
    "super": True,
    "switch": True,
    "synchronized": True,
    "this": True,
    "throw": True,
    "throws": True,
    "transient": True,
    "try": True,
    "void": True,
    "volatile": True,
    "while": True,
    "true": True,
    "false": True,
    "null": True,
}

def _collect_providers(provider, *all_deps):
    """Collects the requested providers from the given list of deps."""
    providers = []
    for deps in all_deps:
        for dep in deps:
            if provider in dep:
                providers.append(dep[provider])
    return providers

def _join_depsets(providers, attr, order = "default"):
    """Returns a merged depset using 'attr' from each provider in 'providers'."""
    return depset(transitive = [getattr(p, attr) for p in providers], order = order)

def _first(collection):
    """Returns the first item in the collection."""
    for i in collection:
        return i
    return _error("The collection is empty.")

def _only(collection):
    """Returns the only item in the collection."""
    if len(collection) != 1:
        _error("Expected one element, has %s." % len(collection))
    return _first(collection)

def _copy_file(ctx, src, dest):
    if src.is_directory or dest.is_directory:
        fail("Cannot use copy_file with directories")
    ctx.actions.run_shell(
        command = "cp --reflink=auto $1 $2",
        arguments = [src.path, dest.path],
        inputs = [src],
        outputs = [dest],
        mnemonic = "CopyFile",
        progress_message = "Copy %s to %s" % (src.short_path, dest.short_path),
    )

def _copy_dir(ctx, src, dest):
    if not src.is_directory:
        fail("copy_dir src must be a directory")
    ctx.actions.run_shell(
        command = "cp -r --reflink=auto $1 $2",
        arguments = [src.path, dest.path],
        inputs = [src],
        outputs = [dest],
        mnemonic = "CopyDir",
        progress_message = "Copy %s to %s" % (src.short_path, dest.short_path),
    )

def _info(msg):
    """Print info."""
    print(_INFO % msg)

def _warn(msg):
    """Print warning."""
    print(_WARNING % msg)

def _debug(msg):
    """Print debug."""
    print("\n%s" % msg)

def _error(msg):
    """Print error and fail."""
    fail(_ERASE_PREV_LINE + _CUU + _ERASE_PREV_LINE + _CUU + _ERROR % msg)

def _expand_var(config_vars, value):
    """Expands make variables of the form $(SOME_VAR_NAME) for a single value.

    "$$(SOME_VAR_NAME)" is escaped to a literal value of "$(SOME_VAR_NAME)" instead of being
    expanded.

    Args:
      config_vars: String dictionary which maps config variables to their expanded values.
      value: The string to apply substitutions to.

    Returns:
      The string value with substitutions applied.
    """
    parts = value.split("$(")
    replacement = parts[0]
    last_char = replacement[-1] if replacement else ""
    for part in parts[1:]:
        var_end = part.find(")")
        if last_char == "$":
            # If "$$(..." is found, treat it as "$(..."
            replacement += "(" + part
        elif var_end == -1 or part[:var_end] not in config_vars:
            replacement += "$(" + part
        else:
            replacement += config_vars[part[:var_end]] + part[var_end + 1:]
        last_char = replacement[-1] if replacement else ""
    return replacement

def _expand_make_vars(ctx, vals):
    """Expands make variables of the form $(SOME_VAR_NAME).

    Args:
      ctx: The rules context.
      vals: Dictionary. Values of the form $(...) will be replaced.

    Returns:
      A dictionary containing vals.keys() and the expanded values.
    """
    res = {}
    for k, v in vals.items():
        res[k] = _expand_var(ctx.var, v)
    return res

def _get_runfiles(ctx, attrs):
    runfiles = ctx.runfiles()
    for attr in attrs:
        executable = attr[DefaultInfo].files_to_run.executable
        if executable:
            runfiles = runfiles.merge(ctx.runfiles([executable]))
        runfiles = runfiles.merge(
            ctx.runfiles(
                # Wrap DefaultInfo.files in depset to strip ordering.
                transitive_files = depset(
                    transitive = [attr[DefaultInfo].files],
                ),
            ),
        )
        runfiles = runfiles.merge(attr[DefaultInfo].default_runfiles)
    return runfiles

def _sanitize_string(s, replacement = ""):
    """Sanitizes a string by replacing all non-word characters.

    This matches the \\w regex character class [A_Za-z0-9_].

    Args:
      s: String to sanitize.
      replacement: Replacement for all non-word characters. Optional.

    Returns:
      The original string with all non-word characters replaced.
    """
    return "".join([s[i] if s[i] in _WORD_CHARS else replacement for i in range(len(s))])

def _hex(n, pad = True):
    """Convert an integer number to an uppercase hexadecimal string.

    Args:
      n: Integer number.
      pad: Optional. Pad the result to 8 characters with leading zeroes. Default = True.

    Returns:
      Return a representation of an integer number as a hexadecimal string.
    """
    hex_str = ""
    for _ in range(8):
        r = n % 16
        n = n // 16
        hex_str = _HEX_CHAR[r] + hex_str
    if pad:
        return hex_str
    else:
        return hex_str.lstrip("0")

def _sanitize_java_package(pkg):
    return ".".join(["xxx" if p in _JAVA_RESERVED else p for p in pkg.split(".")])

def _check_for_failures(label, *all_deps):
    """Collects FailureInfo providers from the given list of deps and fails if there's at least one."""
    failure_infos = _collect_providers(FailureInfo, *all_deps)
    if failure_infos:
        error = "in label '%s':" % label
        for failure_info in failure_infos:
            error += "\n\t" + failure_info.error
        _error(error)

def _run_validation(
        ctx,
        validation_out,
        executable,
        outputs = [],
        tools = [],
        **args):
    """Creates an action that runs an executable as a validation.

    Note: When the validation executable fails, it should return a non-zero
    value to signify a validation failure.

    Args:
      ctx: The context.
      validation_out: A File. The output of the executable is piped to the
        file. This artifact should then be propagated to "validations" in the
        OutputGroupInfo.
      executable: See ctx.actions.run#executable.
      outputs: See ctx.actions.run#outputs.
      tools: See ctx.actions.run#tools.
      **args: Remaining args are directly propagated to ctx.actions.run_shell.
        See ctx.actions.run_shell for further documentation.
    """
    exec_type = type(executable)
    exec_bin = None
    exec_bin_path = None
    if exec_type == "FilesToRunProvider":
        exec_bin = executable.executable
        exec_bin_path = exec_bin.path
    elif exec_type == "File":
        exec_bin = executable
        exec_bin_path = exec_bin.path
    elif exec_type == type(""):
        exec_bin_path = executable
    else:
        fail(
            "Error, executable should be a File, FilesToRunProvider or a " +
            "string that represents a path to a tool, got: %s" % exec_type,
        )

    ctx.actions.run_shell(
        command = """#!/bin/bash
set -eu
set -o pipefail # Returns the executables failure code, if it fails.

EXECUTABLE={executable}
VALIDATION_OUT={validation_out}

"${{EXECUTABLE}}" $@ 2>&1 | tee -a "${{VALIDATION_OUT}}"
""".format(
            executable = exec_bin_path,
            validation_out = validation_out.path,
        ),
        tools = tools + ([exec_bin] if exec_bin else []),
        outputs = [validation_out] + outputs,
        **args
    )

def get_android_toolchain(ctx):
    return ctx.toolchains["@rules_android//toolchains/android:toolchain_type"]

def get_android_sdk(ctx):
    if hasattr(ctx.fragments.android, "incompatible_use_toolchain_resolution") and ctx.fragments.android.incompatible_use_toolchain_resolution:
        return ctx.toolchains["@rules_android//toolchains/android_sdk:toolchain_type"].android_sdk_info
    else:
        return ctx.attr._android_sdk[AndroidSdkInfo]

def _get_compilation_mode(ctx):
    """Retrieves the compilation mode from the context.

    Returns:
      A string that represents the compilation mode.
    """
    return ctx.var["COMPILATION_MODE"]

compilation_mode = struct(
    DBG = "dbg",
    FASTBUILD = "fastbuild",
    OPT = "opt",
    get = _get_compilation_mode,
)

utils = struct(
    check_for_failures = _check_for_failures,
    collect_providers = _collect_providers,
    copy_file = _copy_file,
    copy_dir = _copy_dir,
    expand_make_vars = _expand_make_vars,
    first = _first,
    get_runfiles = _get_runfiles,
    join_depsets = _join_depsets,
    only = _only,
    run_validation = _run_validation,
    sanitize_string = _sanitize_string,
    sanitize_java_package = _sanitize_java_package,
    hex = _hex,
)

log = struct(
    debug = _debug,
    error = _error,
    info = _info,
    warn = _warn,
)

testing = struct(
    expand_var = _expand_var,
)
