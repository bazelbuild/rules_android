"""Hermetic zip helpers backed by @bazel_tools//third_party/ijar:zipper."""

HERMETIC_ZIPPER = Label("@bazel_tools//third_party/ijar:zipper")

def _zipper_tool(ctx, attr_name = "_hermetic_zipper"):
    return getattr(ctx.attr, attr_name)[DefaultInfo].files_to_run

def _zipper_files_to_run(zipper):
    """Return a FilesToRunProvider from a target label or provider."""
    if hasattr(zipper, "executable"):
        return zipper
    return zipper[DefaultInfo].files_to_run

def _zipper_paths(zipper):
    """Return wrapper executable path and runfiles-resident binary path."""
    executable = _zipper_files_to_run(zipper).executable
    wrapper = executable.path
    runfiles = wrapper + ".runfiles/bazel_tools/third_party/ijar/" + executable.basename
    return wrapper, runfiles

def zipper_sandbox_path(zipper):
    """Return the wrapper executable path for a target or FilesToRunProvider."""
    return _zipper_paths(zipper)[0]

def zipper_resolve_bash(zipper, var_name = "zipper"):
    """Return bash that sets ``var_name`` to a sandbox-usable ijar:zipper path."""
    wrapper, runfiles = _zipper_paths(zipper)
    return (
        var_name + '="' + wrapper + '"\n' +
        'if [[ ! -x "${' + var_name + '}" && -x "' + runfiles + '" ]]; then\n' +
        '  ' + var_name + '="' + runfiles + '"\n' +
        'fi\n' +
        'if [[ "${' + var_name + '}" != /* && ! "${' + var_name + '}" =~ ^[A-Za-z]: ]]; then\n' +
        '  ' + var_name + '="${PWD}/${' + var_name + '}"\n' +
        'fi\n'
    )

def zipper_extract(
        ctx,
        *,
        archive,
        output_dir,
        entries = None,
        mnemonic = "ZipperExtract",
        attr_name = "_hermetic_zipper"):
    """Extract ``archive`` into ``output_dir`` using ijar:zipper."""
    zipper_target = getattr(ctx.attr, attr_name)
    entry_args = " ".join(['"{}"'.format(e) for e in entries]) if entries else ""
    ctx.actions.run_shell(
        tools = [zipper_target[DefaultInfo].files_to_run],
        inputs = [archive],
        outputs = [output_dir],
        mnemonic = mnemonic,
        command = """
set -euo pipefail
{resolve}
archive="{archive}"
outdir="{outdir}"
[[ "${{archive}}" != /* && ! "${{archive}}" =~ ^[A-Za-z]: ]] && archive="${{PWD}}/${{archive}}"
[[ "${{outdir}}" != /* && ! "${{outdir}}" =~ ^[A-Za-z]: ]] && outdir="${{PWD}}/${{outdir}}"
mkdir -p "${{outdir}}"
( cd "${{outdir}}" && "${{zipper}}" x "${{archive}}" {entries} )
""".format(
            resolve = zipper_resolve_bash(zipper_target),
            archive = archive.path,
            outdir = output_dir.path,
            entries = entry_args,
        ),
        toolchain = None,
    )

def zipper_create(ctx, *, output, members, mnemonic = "ZipperCreate"):
    """Create ``output`` from ``members`` as (archive_path, file) pairs.

    Args:
      ctx: The rule context.
      output: Output archive file.
      members: List of (archive_path, input_file) pairs.
      mnemonic: Action mnemonic.
    """
    args = ["c", output.path]
    for archive_path, input_file in members:
        args.append("{}={}".format(archive_path, input_file.path))

    ctx.actions.run(
        executable = _zipper_tool(ctx),
        arguments = args,
        inputs = [member[1] for member in members],
        outputs = [output],
        mnemonic = mnemonic,
        toolchain = None,
    )

def run_filter_zip_include(ctx, input_zip, output_zip, filters, zipper_target):
    """Copy ``input_zip`` entries matching ``filters`` globs into ``output_zip``."""
    filter_patterns = " ".join(['"{}"'.format(pattern) for pattern in filters])
    ctx.actions.run_shell(
        tools = [zipper_target[DefaultInfo].files_to_run],
        inputs = [input_zip],
        outputs = [output_zip],
        mnemonic = "FilterZipInclude",
        progress_message = "Filtering %s" % input_zip.short_path,
        command = """
set -euo pipefail
{resolve}
input="{input}"
output="{output}"
[[ "${{input}}" != /* && ! "${{input}}" =~ ^[A-Za-z]: ]] && input="${{PWD}}/${{input}}"
[[ "${{output}}" != /* && ! "${{output}}" =~ ^[A-Za-z]: ]] && output="${{PWD}}/${{output}}"
filters=({filters})
staging=$(mktemp -d)
trap 'rm -rf "${{staging}}"' EXIT
( cd "${{staging}}" && "${{zipper}}" x "${{input}}" )
args=()
while IFS= read -r entry; do
  [[ -z "${{entry}}" ]] && continue
  include=0
  if ((${{#filters[@]}} == 0)); then
    include=1
  else
    for pattern in "${{filters[@]}}"; do
      if [[ "${{entry}}" == ${{pattern}} ]]; then
        include=1
        break
      fi
    done
  fi
  if [[ "${{include}}" -eq 1 ]]; then
    args+=("${{entry}}=${{staging}}/${{entry}}")
  fi
done < <("${{zipper}}" v "${{input}}" | awk '$1 == "f" {{print $3}}')
if ((${{#args[@]}} == 0)); then
  empty=$(mktemp)
  : >"${{empty}}"
  "${{zipper}}" c "${{output}}" "empty=${{empty}}"
else
  "${{zipper}}" c "${{output}}" "${{args[@]}}"
fi
""".format(
            resolve = zipper_resolve_bash(zipper_target),
            input = input_zip.path,
            output = output_zip.path,
            filters = filter_patterns,
        ),
    )

def hermetic_zipper_attr():
    return attr.label(
        cfg = "exec",
        default = HERMETIC_ZIPPER,
    )
