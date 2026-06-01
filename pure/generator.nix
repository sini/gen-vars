# PURE TIER: builtins only, no nixpkgs library.
let
  nameRe = "[a-zA-Z0-9:_.-]+";
  isName = s: builtins.isString s && builtins.match nameRe s != null;
  promptTypes = [
    "hidden"
    "line"
    "multiline"
  ];

  optional = c: v: if c then [ v ] else [ ];
  concatLists = builtins.concatLists;
  attrsToList = f: attrs: map (k: f k attrs.${k}) (builtins.attrNames attrs);

  normalizeFile = genName: fileName: f: {
    name = fileName;
    generator = genName; # backref
    secret = f.secret or true;
    deploy = f.deploy or true; # deploy=false => input-only, never materialized
  };
  normalizePrompt = promptName: p: {
    name = promptName;
    description = p.description or promptName;
    type = p.type or "line";
  };

  mkGenerator = name: g: {
    inherit name;
    dependencies = g.dependencies or [ ];
    files = builtins.mapAttrs (normalizeFile name) (g.files or { });
    prompts = builtins.mapAttrs normalizePrompt (g.prompts or { });
    runtimeInputs = g.runtimeInputs or [ ];
    script = g.script or "";
  };
  normalizeGenerator = mkGenerator;

  # File/prompt validation is INDEPENDENT of name validity.
  validateGenerator =
    g:
    optional (!isName g.name) "gen-vars: invalid generator name ${builtins.toJSON g.name}"
    ++ concatLists (
      attrsToList (
        fn: _:
        optional (!isName fn) "gen-vars: invalid file name ${builtins.toJSON fn} in generator ${g.name}"
      ) g.files
    )
    ++ concatLists (
      attrsToList (
        pn: p:
        optional (
          !builtins.elem p.type promptTypes
        ) "gen-vars: invalid prompt type ${builtins.toJSON p.type} for prompt ${pn} in generator ${g.name}"
      ) g.prompts
    );
in
{
  inherit mkGenerator normalizeGenerator validateGenerator;
}
