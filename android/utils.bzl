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

def _collect_providers(provider, *all_deps):
    """Collects the requested providers from the given list of deps."""
    providers = []
    for deps in all_deps:
        for dep in deps:
            if provider in dep:
                providers.append(dep[provider])
    return providers

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
    print(_ERROR % msg)
    fail(_ERASE_PREV_LINE + _ERASE_PREV_LINE + _CUU)

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
        if v.startswith("$(") and v.endswith(")"):
            res[k] = ctx.var.get(v[2:-1], v)
        else:
            res[k] = v
    return res

def _get_runfiles(ctx, attrs):
    runfiles = ctx.runfiles()
    for attr in attrs:
        executable = attr[DefaultInfo].files_to_run.executable
        if executable:
            runfiles = runfiles.merge(ctx.runfiles([executable]))

        # TODO(timpeut): verify whether this is actually required
        runfiles = runfiles.merge(ctx.runfiles(transitive_files = attr[DefaultInfo].files))
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
    WORD_CHARS = {
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
    return "".join([s[i] if s[i] in WORD_CHARS else replacement for i in range(len(s))])

def _hex(n, pad = True):
    """Convert an integer number to an uppercase hexadecimal string.

    Args:
      n: Integer number.
      pad: Optional. Pad the result to 8 characters with leading zeroes. Default = True.

    Returns:
      Return a representation of an integer number as a hexadecimal string.
    """
    HEX_CHAR = {
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

    hex_str = ""
    for _ in range(8):
        r = n % 16
        n = n // 16
        hex_str = HEX_CHAR[r] + hex_str
    if pad:
        return hex_str
    else:
        return hex_str.lstrip("0")

def get_android_toolchain(ctx):
    return ctx.toolchains["@rules_android//toolchains/android:toolchain_type"]

utils = struct(
    collect_providers = _collect_providers,
    expand_make_vars = _expand_make_vars,
    first = _first,
    get_runfiles = _get_runfiles,
    only = _only,
    sanitize_string = _sanitize_string,
    hex = _hex,
)

log = struct(
    debug = _debug,
    error = _error,
    info = _info,
    warn = _warn,
)
