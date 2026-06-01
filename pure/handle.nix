# PURE TIER: builtins only, no nixpkgs library.
# Option-1 handle: a pure record carrying NO resolution and NO deploy.
# deploy lives only on plan-entry files, never on a handle.
{
  mkHandle =
    {
      generator,
      name,
      secret ? true,
    }:
    {
      inherit generator name secret;
    };
  handleId = h: "${h.generator}/${h.name}";
  handlesOf =
    g:
    map (f: {
      generator = g.name;
      name = f.name;
      secret = f.secret;
    }) (builtins.attrValues g.files);
}
