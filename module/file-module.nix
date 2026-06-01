{ lib }:
{
  fileModuleSlot = lib.mkOption {
    type = lib.types.deferredModule;
    internal = true;
    default = { };
    description = ''
      Imported into every files.<f> submodule. A resolver returns an attrset setting at least
      `path`. ONE deferredModule slot per evaluation — that single-target ceiling is exactly why
      den's MULTI-target lives in the den adapter's per-class resolver registry, not here.
    '';
  };
  mkOnMachineResolver =
    { fileLocation }:
    file: {
      path =
        let
          bucket = if file.config.secret then "secret" else "public";
        in
        "${fileLocation}/${bucket}/${file.config.generator}/${file.config.name}";
    };
}
