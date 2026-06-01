# PURE TIER: builtins only, no nixpkgs library.
# A resolver is a plain `handle -> resolution`. `resolution` is an OPEN type:
# any class-native value (a path string, a terranix ref attrset, ...). The core
# holds NO resolution itself.
{
  mkResolver = f: f; # identity/doc tag
  resolve = resolver: handle: resolver handle;
  # THE MULTI-TARGET PROPERTY: same handle, >=2 resolvers, ONE evaluation.
  resolveAll = resolvers: handle: builtins.mapAttrs (_target: resolver: resolver handle) resolvers;
}
