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

"""Bazel Path APIs for the Android rules."""

# TODO(djwhang): Get the path separator in a platform agnostic manner.
_PATH_SEP = "/"
_TEST_SRCDIR = "${TEST_SRCDIR}"

def _is_absolute(path):
    # TODO(djwhang): This is not cross platform safe. Windows absolute paths
    # do not start with "//", rather "C:\".
    return path.startswith(_PATH_SEP)

def _split(path):
    return path.split(_PATH_SEP)

def _join(path_segments):
    return _PATH_SEP.join(path_segments)

def _normalize_path(path, posix = False):
    return _PATH_SEP.join(
        _normalize_path_fragments(
            path.split(_PATH_SEP),
            posix = posix,
        ),
    )

def _normalize_path_fragments(path_fragments, posix = False):
    normalized_path_fragments = []
    for idx, fragment in enumerate(path_fragments):
        if not fragment and idx > 0:
            continue
        if fragment == ".":
            continue
        if fragment == ".." and not posix:
            if normalized_path_fragments:
                last = normalized_path_fragments.pop()
                if last == ".." or last == "":
                    normalized_path_fragments.append(last)
                else:
                    continue
        normalized_path_fragments.append(fragment)
    if len(normalized_path_fragments) == 1 and not normalized_path_fragments[0]:
        normalized_path_fragments.append("")
    return normalized_path_fragments

def _relative_path(path1, path2):
    if not path1 or _is_absolute(path2):
        return path2

    path1_fragments = _normalize_path_fragments(_split(path1))
    path2_fragments = _normalize_path_fragments(_split(path2))
    path1_idx = len(path1_fragments)  # index move backwards
    path2_idx = -1
    for idx, fragment in enumerate(path2_fragments):
        if fragment == "..":
            path1_idx -= 1
        else:
            path2_idx = idx
            break

    relative_path_fragments = []
    if path1_idx >= 0:
        relative_path_fragments.extend(path1_fragments[:path1_idx])
    if path2_idx >= 0:
        relative_path_fragments.extend(path2_fragments[path2_idx:])
    return _join(_normalize_path_fragments(relative_path_fragments))

def _make_test_srcdir_path(ctx, *path_fragments):
    """Creates a filepath relative to TEST_SRCDIR.

    Args:
        ctx: Starlark context.
        *path_fragments: Directories/file to join into a single path.
    Returns:
        A filepath that's spearated by the host's filepath separator.
    """
    fragments = [_TEST_SRCDIR, ctx.workspace_name]
    for path_fragment in path_fragments:
        fragments += _normalize_path_fragments(_split(path_fragment))
    return _join(fragments)

path = struct(
    is_absolute = _is_absolute,
    join = _join,
    normalize = _normalize_path,
    relative = _relative_path,
    split = _split,
    make_test_srcdir_path = _make_test_srcdir_path,
)
