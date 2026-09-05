"""Starlark replacements for desugar genrules that previously called host zip/unzip."""

load("//toolchains/android:zipper.bzl", "hermetic_zipper_attr", "zipper_extract", "zipper_resolve_bash")

def _extract_desugar_config_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)
    extracted = ctx.actions.declare_directory(ctx.label.name + "_extracted")
    zipper_extract(
        ctx,
        archive = ctx.file.jar,
        output_dir = extracted,
        entries = ["META-INF/desugar/d8/desugar.json"],
        mnemonic = "ExtractDesugarConfig",
    )
    ctx.actions.run_shell(
        inputs = [extracted],
        outputs = [out],
        command = "cp '{src}/META-INF/desugar/d8/desugar.json' '{out}'".format(
            src = extracted.path,
            out = out.path,
        ),
        mnemonic = "WriteDesugarConfigJson",
    )
    return [DefaultInfo(files = depset([out]))]

extract_desugar_config_json = rule(
    implementation = _extract_desugar_config_impl,
    attrs = {
        "jar": attr.label(mandatory = True, allow_single_file = True),
        "out": attr.string(mandatory = True),
        "_hermetic_zipper": hermetic_zipper_attr(),
    },
)

def _desugar_globals_jar_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)
    extracted = ctx.actions.declare_directory(ctx.label.name + "_extracted")
    zipper_extract(
        ctx,
        archive = ctx.file.classes,
        output_dir = extracted,
        mnemonic = "ExtractDesugarGlobals",
    )
    resolve = zipper_resolve_bash(ctx.attr._hermetic_zipper)
    ctx.actions.run_shell(
        inputs = [extracted],
        outputs = [out],
        tools = [ctx.attr._hermetic_zipper[DefaultInfo].files_to_run],
        command = (
            resolve +
            """
set -euo pipefail
src="{src}"
out="{out}"
[[ "${{src}}" != /* && ! "${{src}}" =~ ^[A-Za-z]: ]] && src="${{PWD}}/${{src}}"
[[ "${{out}}" != /* && ! "${{out}}" =~ ^[A-Za-z]: ]] && out="${{PWD}}/${{out}}"
work=$(mktemp -d)
cp -R "${{src}}"/. "${{work}}"/
cd "${{work}}"
rm -f kind compilerinfo
for f in $(find . -name '*.global'); do
  mv "$f" "${{f%%.global}}.class"
done
args=()
while IFS= read -r -d '' f; do
  relpath=${{f#./}}
  args+=("${{relpath}}=${{f}}")
done < <(find . -type f -print0)
if [ ${{#args[@]}} -eq 0 ]; then
  empty=$(mktemp)
  : >"${{empty}}"
  "${{zipper}}" c "${{out}}" "empty=${{empty}}"
else
  "${{zipper}}" c "${{out}}" "${{args[@]}}"
fi
""".format(
                src = extracted.path,
                out = out.path,
            )
        ),
        mnemonic = "RepackDesugarGlobalsJar",
    )
    return [DefaultInfo(files = depset([out]))]

desugar_globals_jar = rule(
    implementation = _desugar_globals_jar_impl,
    attrs = {
        "classes": attr.label(mandatory = True, allow_single_file = [".zip"]),
        "out": attr.string(mandatory = True),
        "_hermetic_zipper": hermetic_zipper_attr(),
    },
)
