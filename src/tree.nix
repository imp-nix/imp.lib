# Builds a nested attrset from directory structure (Flakelight-style autoload)
#
# Naming conventions:
#   foo.nix or foo/default.nix -> { foo = <imported>; }
#   foo_.nix -> { foo = <imported>; }  (trailing _ escapes reserved names e.g. `default`)
#   _foo.nix or _foo/ -> ignored
{
  lib,
  treef ? import,
  filterf,
}:
let
  buildTree =
    root:
    let
      entries = builtins.readDir root;

      toAttrName =
        name:
        let
          withoutNix = lib.removeSuffix ".nix" name;
        in
        lib.removeSuffix "_" withoutNix;

      shouldInclude = name: !(lib.hasPrefix "_" name) && filterf (toString root + "/" + name);

      processEntry =
        name: type:
        let
          path = root + "/${name}";
          attrName = toAttrName name;
        in
        if type == "regular" && lib.hasSuffix ".nix" name then
          { ${attrName} = treef path; }
        else if type == "directory" then
          let
            hasDefault = builtins.pathExists (path + "/default.nix");
          in
          if hasDefault then { ${attrName} = treef path; } else { ${attrName} = buildTree path; }
        else
          { };

      filteredEntries = lib.filterAttrs (name: _: shouldInclude name) entries;
      processed = lib.mapAttrsToList processEntry filteredEntries;
    in
    lib.foldl' (acc: x: acc // x) { } processed;
in
buildTree
