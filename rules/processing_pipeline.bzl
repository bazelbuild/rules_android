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

"""Common implementation for processing pipelines."""

PROVIDERS = "providers"
VALIDATION_OUTPUTS = "validation_outputs"

# TODO(djwhang): When a provider type can be retrieved from a Starlark provider
# ProviderInfo is necessary. Once this is possible, processor methods can have a
# uniform method signature foo(ctx, target_ctx) where we can pull the provider
# off the target_ctx using the provider type.
#
# Yes, this effectively leads to producing a build rule like system within a
# build rule, rather than resorting to rule based composition.
ProviderInfo = provider(
    "Stores metadata about the actual Starlark provider returned.",
    fields = dict(
        name = "The type of the provider",
        value = "The actual provider",
        runfiles = "Runfiles to pass to the DefaultInfo provider",
    ),
)

_ProcessingPipelineInfo = provider(
    "Stores functions that forms a rule's implementation.",
    fields = dict(
        processors = "Ordered dictionary of processing functions.",
        finalize = "Function to form the final providers to propagate.",
    ),
)

def _make_processing_pipeline(processors = dict(), finalize = None):
    """Creates the combined processing pipeline.

    Args:
      processors: Ordered dictionary of processing functions.
      finalize: Function to form the final providers to propagate.

    Returns:
      A _ProcessingPipelineInfo provider.
    """
    return _ProcessingPipelineInfo(
        processors = processors,
        finalize = finalize,
    )

def _run(ctx, java_package, processing_pipeline):
    """Runs the processing pipeline and populates the target context.

    Args:
      ctx: The context.
      java_package: The java package resolved from the target's path
        or the custom_package attr.
      processing_pipeline: The _ProcessingPipelineInfo provider for this target.

    Returns:
      The output of the _ProcessingPipelineInfo.finalize function.
    """
    target_ctx = dict(
        java_package = java_package,
        providers = [],
        validation_outputs = [],
        runfiles = ctx.runfiles(),
    )

    for execute in processing_pipeline.processors.values():
        info = execute(ctx, **target_ctx)
        if info:
            if info.name in target_ctx:
                fail("%s provider already registered in target context" % info.name)
            target_ctx[info.name] = info.value
            target_ctx[PROVIDERS].extend(getattr(info.value, PROVIDERS, []))
            target_ctx[VALIDATION_OUTPUTS].extend(getattr(info.value, VALIDATION_OUTPUTS, []))
            if hasattr(info, "runfiles") and info.runfiles:
                target_ctx["runfiles"] = target_ctx["runfiles"].merge(info.runfiles)

    return processing_pipeline.finalize(ctx, **target_ctx)

def _prepend(processors, **new_processors):
    """Prepends processors in a given processing pipeline.

    Args:
      processors: The dictionary representing the processing pipeline.
      **new_processors: The processors to add where the key represents the
        name of the processor and value is the function pointer to the new
        processor.

    Returns:
      A dictionary which represents the new processing pipeline.
    """
    updated_processors = dict()
    for name, processor in new_processors.items():
        updated_processors[name] = processor

    for key in processors.keys():
        updated_processors[key] = processors[key]

    return updated_processors

def _append(processors, **new_processors):
    """Appends processors in a given processing pipeline.

    Args:
      processors: The dictionary representing the processing pipeline.
      **new_processors: The processors to append where the key represents the
        name of the processor and value is the function pointer to the new
        processor.

    Returns:
      A dictionary which represents the new processing pipeline.
    """
    updated_processors = dict(processors)
    for name, processor in new_processors.items():
        updated_processors[name] = processor

    return updated_processors

def _replace(processors, **new_processors):
    """Replace processors in a given processing pipeline.

    Args:
      processors: The dictionary representing the processing pipeline.
      **new_processors: The processors to override where the key represents the
        name of the processor and value is the function pointer to the new
        processor.

    Returns:
      A dictionary which represents the new processing pipeline.
    """
    updated_processors = dict(processors)
    for name, processor in new_processors.items():
        if name not in processors:
            fail("Error, %s not found, unable to override." % name)

        # NOTE: Overwriting an existing value does not break iteration order.
        # However, if a new processor is being added that needs to be injected
        # between other processors, the processing pipeline dictionary will need
        # to be recreated.
        updated_processors[name] = processor

    return updated_processors

processing_pipeline = struct(
    make_processing_pipeline = _make_processing_pipeline,
    run = _run,
    prepend = _prepend,
    append = _append,
    replace = _replace,
)
