# Description:
#   Package for aar_import validation checks
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

genrule(
    name = "gen_aar_import_checks",
    outs = ["aar_import_checks.sh"],
    cmd = """
cat > $@ <<"EOF"
#!/bin/bash
while [[ $$# -gt 0 ]]
do
  case $$1 in
      -output)
      out="$$2"
      ;;
  esac
  shift # past argument
  shift # past value
done
touch $$out
EOF
""",
    executable = True,
)

sh_binary(
    name = "aar_import_checks_bin",
    srcs = [":aar_import_checks.sh"],
)

# sh_binary produces 3 outputs, while the aar_import_checks label attr in the
# Android toolchain expects a single file, so we need to pick out just the exe.
genrule(
    name = "get_aar_import_checks_exe",
    srcs = [":aar_import_checks_bin"],
    outs = ["aar_import_checks.exe"],
    cmd = """cp "$$(find . -type f | grep 'aar_import_checks_bin.exe$$' | head -1)" "$@" """,
    tags = ["manual"],
)

config_setting(
    name = "windows",
    constraint_values = ["@platforms//os:windows"],
)

alias(
    name = "aar_import_checks",
    actual = select({
        ":windows": "aar_import_checks.exe",
        "//conditions:default": "gen_aar_import_checks",
    }),
)