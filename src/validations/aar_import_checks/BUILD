# Description:
#   Package for aar_import validation checks
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

genrule(
    name = "gen_aar_import_checks",
    outs = ["aar_import_checks"],
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
