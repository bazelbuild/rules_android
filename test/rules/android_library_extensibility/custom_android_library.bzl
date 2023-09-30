# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Custom android_library for use in test.bzl"""

load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)
load(
    "//rules:java.bzl",
    _java = "java",
)
load(
    "//rules:processing_pipeline.bzl",
    _ProviderInfo = "ProviderInfo",
    _processing_pipeline = "processing_pipeline",
)
load(
    "//rules/android_library:attrs.bzl",
    _BASE_ATTRS = "ATTRS",
)
load(
    "//rules/android_library:impl.bzl",
    _BASE_PROCESSORS = "PROCESSORS",
    _finalize = "finalize",
)
load(
    "//rules/android_library:rule.bzl",
    _make_rule = "make_rule",
)

CustomProviderInfo = provider(
    doc = "Custom provider to provide",
    fields = dict(
        key = "Some key to provide",
    ),
)

def _process_custom_provider(ctx, **_unused_sub_ctxs):
    return _ProviderInfo(
        name = "custom_provider_ctx",
        value = struct(
            providers = [
                CustomProviderInfo(
                    key = ctx.attr.key,
                ),
            ],
        ),
    )

PROCESSORS = _processing_pipeline.append(
    _BASE_PROCESSORS,
    CustomProviderInfoProcessor = _process_custom_provider,
)

_PROCESSING_PIPELINE = _processing_pipeline.make_processing_pipeline(
    processors = PROCESSORS,
    finalize = _finalize,
)

def _impl(ctx):
    java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.custom_package)
    return _processing_pipeline.run(ctx, java_package, _PROCESSING_PIPELINE)

custom_android_library = _make_rule(
    implementation = _impl,
    attrs = _attrs.add(_BASE_ATTRS, dict(
        # Custom attribute to wrap in a provider
        key = attr.string(),
    )),
    additional_providers = [
        CustomProviderInfo,
    ],
)
