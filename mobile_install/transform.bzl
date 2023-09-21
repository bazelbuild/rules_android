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
"""Transform contains data transformation methods."""

load(":constants.bzl", "constants")
load(":utils.bzl", "utils")
load("//rules/flags:flags.bzl", _flags = "flags")

def _declare_file(ctx, filename, sibling = None):
    return utils.isolated_declare_file(ctx, filename, sibling = sibling)

def filter_jars(name, data):
    """Filters out files that are not compiled Jars - includes header Jars.

    Args:
      name: Name of the file to filter, check uses endswith on the path.
      data: The list of tuples where each entry contains the originating file path
        and file to apply the filter.

    Returns:
      A list of tuples where each entry contains the originating Jar path and the
      Jar file.
    """
    return [jar for jar in data if not jar.path.endswith(name)]

def dex(
        ctx,
        data,
        deps = constants.EMPTY_LIST,
        num_shards = None,
        create_file = _declare_file,
        desugar = True):
    """Dex a list of Jars.

    Args:
      ctx: The context.
      data: The list of tuples where each entry contains the originating Jar
        path and the Jar to Dex.
      deps: The list of dependencies for the Jar being desugared.
      num_shards: The number of shards to distribute the dexed files across,
        this value overrides the default provided by ctx.attr._mi_dex_shards.
      create_file: In rare occasions a custom method is required to
        create a unique file, override the default here. The method must
        implement the following interface:

        def create_file(ctx, filename, sibling = None)
        Args:
          ctx: The context.
          filename: string. The name of the file.
          sibling: File. The location of the new file.

        Returns:
          A File.
      desugar: A boolean that determines whether to apply desugaring.

    Returns:
      A list of tuples where each entry contains the originating Jar path and
      the Dex shards.
    """
    if num_shards:
        num_dex_shards = num_shards
    elif _flags.get(ctx).use_custom_dex_shards:
        num_dex_shards = _flags.get(ctx).num_dex_shards
    else:
        num_dex_shards = ctx.attr._mi_dex_shards

    dex_files = []
    for jar in data:
        out_dex_shards = []
        dirname = jar.basename + "_dex"
        for i in range(num_shards or num_dex_shards):
            out_dex_shards.append(create_file(
                ctx,
                dirname + "/" + str(i) + ".zip",
                sibling = jar,
            ))
        utils.dex(ctx, jar, out_dex_shards, deps, desugar)
        dex_files.append(out_dex_shards)
    return dex_files

def extract_jar_resources(ctx, data, create_file = _declare_file):
    """Extracts the non-class files from the list of Jars.

    Args:
      ctx: The context
      data: The list of tuples where each entry contains the originating Jar
        path and the Jar with resources to extract.
      create_file: In rare occasions a custom method is required to
        create a unique file, override the default here. The method must
        implement the following interface:

        def create_file(ctx, filename, sibling = None)
        Args:
          ctx: The context.
          filename: string. The name of the file.
          sibling: File. The location of the new file.

        Returns:
          A File.

    Returns:
      A list of extracted resource zips.
    """
    resources_files = []
    for jar in data:
        out_resources_file = create_file(
            ctx,
            jar.basename + "_resources.zip",
            sibling = jar,
        )
        utils.extract_jar_resources(ctx, jar, out_resources_file)
        resources_files.append(out_resources_file)
    return resources_files

def merge_dex_shards(ctx, data, sibling):
    """Merges all dex files in the transitive deps to a dex per shard.

    Given a list of dex files (and resources.zips) this will create an
    action per shard that runs dex_shard_merger on all dex files within that
    shard.

    Arguments:
      ctx: The context.
      data: A list of lists, where the inner list contains dex shards.
      sibling: A file used to root the merged_dex shards.

    Returns:
      A list of merged dex shards.
    """
    merged_dex_shards = []
    for idx, shard in enumerate(data):
        #  To ensure resource is added at the beginning, R.zip is named as 00.zip
        #  Thus data shards starts from 1 instead of 0 and ranges through 16
        idx += 1

        # Shards are sorted before deployment, to ensure all shards are correctly
        # ordered 0 is padded to single digit shard counts
        shard_name = "%s%s" % ("00"[len(str(idx)):], idx)
        merged_dex_shard = utils.isolated_declare_file(
            ctx,
            "dex_shards/" + shard_name + ".zip",
            sibling = sibling,
        )
        utils.merge_dex_shards(ctx, shard, merged_dex_shard)
        merged_dex_shards.append(merged_dex_shard)
    return merged_dex_shards
