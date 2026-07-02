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

"""POM generation for fat_aar targets.

This rule generates a Maven POM file from a fat_aar's excluded dependencies.
"""

load("//rules/fat_aar:aspect.bzl", "FatAarDependenciesInfo")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

def _pom_from_fat_aar_impl(ctx):
    """Generates a Maven POM file from a fat_aar's excluded dependencies.

    Args:
      ctx: The context.

    Returns:
      DefaultInfo with the generated POM file.
    """
    pom_file = ctx.actions.declare_file(ctx.label.name + ".pom")

    excluded_labels = ctx.attr.fat_aar[FatAarDependenciesInfo].excluded_labels.to_list()

    # Build a mapping from Bazel label to Maven coordinate
    # maven_coords format: "group:artifact:type:version"
    label_to_coord = {}
    for coord in ctx.attr.maven_coords:
        parts = coord.split(":")
        if len(parts) >= 2:
            group = parts[0]
            artifact = parts[1]
            # Convert to Bazel label format
            label_name = "{}_{}".format(group, artifact).replace(".", "_").replace("-", "_")
            maven_label = "@maven//:{}".format(label_name)
            label_to_coord[maven_label] = coord

    # Match excluded labels to Maven coordinates
    matched_coords = {}
    for label in excluded_labels:
        label_str = str(label)
        # Handle both @maven// and @@maven// formats
        if "@maven//" not in label_str:
            continue

        # Extract the target name after the last ':'
        if ":" not in label_str:
            continue
        target = label_str.split(":")[-1]

        # Skip special targets
        if target.startswith("jarinfer_") or target.startswith("proguard_") or target.startswith("v1"):
            continue

        # Try to find matching coordinate
        check_label = "@maven//:{}".format(target)
        if check_label in label_to_coord:
            coord = label_to_coord[check_label]
            matched_coords[coord] = True

    # Generate POM dependencies XML
    dependencies_xml = ""
    for coord in sorted(matched_coords.keys()):
        parts = coord.split(":")
        classifier = None
        if len(parts) == 3:
            # Format: group:artifact:version or group:artifact:version@type
            group_id = parts[0]
            artifact_id = parts[1]
            version_part = parts[2]
            if "@" in version_part:
                version, packaging = version_part.split("@", 1)
            else:
                version = version_part
                packaging = None
        elif len(parts) == 4:
            # Format: group:artifact:type:version
            group_id = parts[0]
            artifact_id = parts[1]
            packaging = parts[2]
            version = parts[3]
        elif len(parts) == 5:
            # Format: group:artifact:type:classifier:version
            group_id = parts[0]
            artifact_id = parts[1]
            packaging = parts[2]
            classifier = parts[3]
            version = parts[4]
        else:
            continue

        classifier_xml = ""
        if classifier:
            classifier_xml = "      <classifier>{classifier}</classifier>\n".format(classifier = classifier)

        packaging_xml = ""
        if packaging:
            packaging_xml = "      <type>{packaging}</type>\n".format(packaging = packaging)

        dependencies_xml += """    <dependency>
      <groupId>{group_id}</groupId>
      <artifactId>{artifact_id}</artifactId>
      <version>{version}</version>
{packaging_xml}{classifier_xml}      <scope>compile</scope>
    </dependency>
""".format(group_id = group_id, artifact_id = artifact_id, version = version, packaging_xml = packaging_xml, classifier_xml = classifier_xml)

    pom_content = """<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>{group_id}</groupId>
  <artifactId>{artifact_id}</artifactId>
  <version>{version}</version>
  <packaging>aar</packaging>

  <dependencies>
{dependencies}  </dependencies>
</project>
""".format(
        group_id = ctx.attr.group_id,
        artifact_id = ctx.attr.artifact_id,
        version = ctx.attr.version,
        dependencies = dependencies_xml,
    )

    ctx.actions.write(
        output = pom_file,
        content = pom_content,
    )

    return [
        DefaultInfo(
            files = depset([pom_file]),
        ),
    ]

fat_aar_pom = rule(
    implementation = _pom_from_fat_aar_impl,
    attrs = {
        "fat_aar": attr.label(
            mandatory = True,
            providers = [FatAarDependenciesInfo],
            doc = "The fat_aar target to generate POM for",
        ),
        "maven_coords": attr.string_list(
            mandatory = True,
            doc = "List of all Maven coordinates to match against (e.g., from maven_artifacts.bzl)",
        ),
        "group_id": attr.string(
            mandatory = True,
            doc = "Maven group ID for the POM",
        ),
        "artifact_id": attr.string(
            mandatory = True,
            doc = "Maven artifact ID for the POM",
        ),
        "version": attr.string(
            mandatory = True,
            doc = "Maven version for the POM",
        ),
    },
    doc = "Generates a Maven POM file from a fat_aar's excluded dependencies by looking them up in the provided maven_coords list.",
)
