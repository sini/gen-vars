{ lib }:
{
  plan,
  fileLocation ? "/etc/vars",
}:
let
  entries = plan.order;
  promptCmd = {
    hidden = "read -sr prompt_value";
    line = "read -r prompt_value";
    multiline = "echo 'press control-d to finish'\n        prompt_value=$(cat)";
  };
  pathOf =
    gen: file: ''"$OUT_DIR"/${if file.secret then "secret" else "public"}/${gen.name}/${file.name}'';
  byName = lib.listToAttrs (map (g: lib.nameValuePair g.name g) entries);
  genBlock = gen: ''
    all_files_missing=true ; all_files_present=true
    ${lib.concatMapStringsSep "\n" (file: ''
      if test -e ${pathOf gen file} ; then all_files_missing=false ; else all_files_present=false ; fi
    '') gen.files}
    if [ $all_files_missing = false ] && [ $all_files_present = false ] ; then
      echo "gen-vars: inconsistent state for generator: ${gen.name}" ; exit 1
    fi
    if [ $all_files_present = true ] ; then echo "all files for ${gen.name} present"
    elif [ $all_files_missing = true ] ; then
      prompts=$(mktemp -d) ; export prompts ; trap 'rm -rf "$prompts"' EXIT
      ${lib.concatMapStringsSep "\n" (p: ''
        echo ${lib.escapeShellArg p.description}
        ${promptCmd.${p.type}}
        printf '%s' "$prompt_value" > "$prompts"/${p.name}
      '') gen.prompts}
      in=$(mktemp -d) ; export in ; trap 'rm -rf "$in"' EXIT
      ${lib.concatMapStringsSep "\n" (dep: ''
        mkdir -p "$in"/${dep}
        ${lib.concatMapStringsSep "\n" (f: ''
          cp "$OUT_DIR"/${if f.secret then "secret" else "public"}/${dep}/${f.name} "$in"/${dep}/${f.name}
        '') (byName.${dep}.files or [ ])}
      '') gen.dependencies}
      out=$(mktemp -d) ; export out ; trap 'rm -rf "$out"' EXIT
      ( unset PATH
        ${lib.optionalString (
          gen.runtimeInputs != [ ]
        ) "PATH=${lib.makeBinPath gen.runtimeInputs} ; export PATH"}
        ${gen.script} )
      ${lib.concatMapStringsSep "\n" (f: ''
        test -e "$out"/${f.name} || { echo "gen-vars: ${gen.name} failed to produce ${f.name}" ; exit 1 ; }
      '') gen.files}
      ${lib.concatMapStringsSep "\n" (
        f:
        lib.optionalString f.deploy ''
          OUT_FILE=${pathOf gen f}
          mkdir -p "$(dirname "$OUT_FILE")" ; mv "$out"/${f.name} "$OUT_FILE"
        ''
      ) gen.files}
    fi
  '';
in
''
  set -efuo pipefail
  OUT_DIR=''${OUT_DIR:-${fileLocation}}
  ${lib.concatMapStringsSep "\n" genBlock entries}
''
