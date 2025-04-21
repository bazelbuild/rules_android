# Description:
#   Package for aar_import validation checks
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//:__pkg__"]
)

genrule(
    name = "gen_aar_import_checks_sh",
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

genrule(
    name = "gen_aar_import_checks_bat",
    outs = ["aar_import_checks.bat"],
    cmd = """
cat > $@ <<"EOF"
@ECHO OFF
:args
IF "%~1"=="-output" (
  GOTO create_output
) ELSE IF "%~1"=="" (
  EXIT /B 1
)
SHIFT
GOTO args
:create_output
SHIFT
copy /y NUL "%~1" >NUL

EOF
""",
    executable = True,
)

config_setting(
    name = "windows",
    constraint_values = ["@platforms//os:windows"],
)

alias(
    name = "aar_import_checks",
    actual = select({
        ":windows": "aar_import_checks.bat",
        "//conditions:default": "aar_import_checks.sh",
    }),
)