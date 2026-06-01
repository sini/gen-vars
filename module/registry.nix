{ lib }:
let
  mkFileType =
    settings: genName:
    lib.types.submodule (file: {
      imports = [ settings.fileModule ]; # the resolver seam (Option 3)
      options = {
        name = lib.mkOption {
          type = lib.types.strMatching "[a-zA-Z0-9:_.-]*";
          readOnly = true;
          default = file.config._module.args.name;
        };
        generator = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          internal = true;
          default = genName;
        };
        deploy = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        secret = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        path = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        value = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
    });
in
rec {
  generatorsType =
    settings:
    lib.types.attrsOf (
      lib.types.submodule (gen: {
        options = {
          name = lib.mkOption {
            type = lib.types.strMatching "[a-zA-Z0-9:_.-]*";
            readOnly = true;
            default = gen.config._module.args.name;
          };
          dependencies = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          files = lib.mkOption {
            type = lib.types.attrsOf (mkFileType settings gen.config._module.args.name);
            default = { };
          };
          prompts = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (p: {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    default = p.config._module.args.name;
                  };
                  description = lib.mkOption {
                    type = lib.types.str;
                    default = p.config._module.args.name;
                  };
                  type = lib.mkOption {
                    type = lib.types.enum [
                      "hidden"
                      "line"
                      "multiline"
                    ];
                    default = "line";
                  };
                };
              })
            );
            default = { };
          };
          runtimeInputs = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
          };
          script = lib.mkOption {
            type = lib.types.either lib.types.str lib.types.path;
            default = "";
          };
        };
      })
    );
  generatorsOption =
    settings:
    lib.mkOption {
      type = generatorsType settings;
      default = { };
    };
}
