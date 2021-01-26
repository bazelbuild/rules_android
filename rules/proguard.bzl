# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""Bazel Android Proguard library for the Android rules."""

_ProguardContextInfo = provider(
    doc = "Contains data from processing Proguard specs.",
    fields = dict(
        proguard_configs = "The direct proguard configs",
        transitive_proguard_configs =
            "The proguard configs within the transitive closure of the target",
        providers = "The list of all providers to propagate.",
    ),
)

def _validate_proguard_spec(
        ctx,
        out_validated_proguard_spec,
        proguard_spec,
        proguard_allowlister):
    args = ctx.actions.args()
    args.add("--path", proguard_spec)
    args.add("--output", out_validated_proguard_spec)

    ctx.actions.run(
        executable = proguard_allowlister,
        arguments = [args],
        inputs = [proguard_spec],
        outputs = [out_validated_proguard_spec],
        mnemonic = "ValidateProguard",
        progress_message = (
            "Validating proguard configuration %s" % proguard_spec.short_path
        ),
    )

def _process(
        ctx,
        proguard_configs = [],
        proguard_spec_providers = [],
        proguard_allowlister = None):
    """Processes Proguard Specs

    Args:
      ctx: The context.
      proguard_configs: sequence of Files. A list of proguard config files to be
        processed. Optional.
      proguard_spec_providers: sequence of ProguardSpecProvider providers. A
        list of providers from the dependencies, exports, plugins,
        exported_plugins, etc. Optional.
      proguard_allowlister: The proguard_allowlister exeutable provider.

    Returns:
      A _ProguardContextInfo provider.
    """

    # TODO(djwhang): Look to see if this can be just a validation action and the
    # proguard_spec provided by the rule can be propagated.
    validated_proguard_configs = []
    for proguard_spec in proguard_configs:
        validated_proguard_spec = ctx.actions.declare_file(
            "validated_proguard/%s/%s_valid" %
            (ctx.label.name, proguard_spec.path),
        )
        _validate_proguard_spec(
            ctx,
            validated_proguard_spec,
            proguard_spec,
            proguard_allowlister,
        )
        validated_proguard_configs.append(validated_proguard_spec)

    transitive_validated_proguard_configs = []
    for info in proguard_spec_providers:
        transitive_validated_proguard_configs.append(info.specs)

    transitive_proguard_configs = depset(
        validated_proguard_configs,
        transitive = transitive_validated_proguard_configs,
        order = "preorder",
    )
    return _ProguardContextInfo(
        proguard_configs = proguard_configs,
        transitive_proguard_configs = transitive_proguard_configs,
        providers = [
            ProguardSpecProvider(transitive_proguard_configs),
            # TODO(b/152659272): Remove this once the android_archive rule is
            # able to process a transitive closure of deps to produce an aar.
            AndroidProguardInfo(proguard_configs),
        ],
    )

proguard = struct(
    process = _process,
)

testing = struct(
    validate_proguard_spec = _validate_proguard_spec,
    ProguardContextInfo = _ProguardContextInfo,
)
