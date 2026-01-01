/**
  Builds nested attrset from directory structure.

  Naming:  `foo.nix` | `foo/default.nix` -> `{ foo = ... }`
           `foo_.nix`                  -> `{ foo = ... }`  (escapes reserved names)
           `_foo.nix` | `_foo/`          -> ignored
           `foo.d/`                      -> fragment directory (merged attrsets)

  Fragment directories (`*.d/`):
    Files in `foo.d/` are imported, called with treef, and merged using
    `lib.recursiveUpdate`. Files are processed in sorted order (00-base.nix
    before 10-extra.nix). This enables composable configuration where
    multiple sources can contribute to a single output attribute.

  Conflict detection:
    If both `foo.nix` and `foo.d/` exist, an error is thrown. Choose one
    pattern or the other, not both.

  # Example

  Directory structure:

  ```
  outputs/
    apps.nix
    checks.nix
    packages.d/
      00-core.nix       # { default = ...; foo = ...; }
      10-extras.nix     # { bar = ...; }
  ```

  ```nix
  imp.treeWith lib import ./outputs
  ```

  Returns:

  ```nix
  {
    apps = <imported from apps.nix>;
    checks = <imported from checks.nix>;
    packages = { default = ...; foo = ...; bar = ...; };  # merged
  }
  ```

  # Usage

  ```nix
  (imp.withLib lib).tree ./outputs
  ```

  Or with transform:

  ```nix
  ((imp.withLib lib).mapTree (f: f args)).tree ./outputs
  imp.treeWith lib (f: f args) ./outputs
  ```
*/
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
          # Remove .nix suffix
          withoutNix = lib.removeSuffix ".nix" name;
          # Remove .d suffix for fragment directories
          withoutD = lib.removeSuffix ".d" withoutNix;
        in
        lib.removeSuffix "_" withoutD;

      # Check if a .d directory has a conflicting .nix file
      hasConflict =
        name:
        let
          baseName = lib.removeSuffix ".d" name;
          nixFile = baseName + ".nix";
        in
        lib.hasSuffix ".d" name && entries ? ${nixFile};

      # Skip underscore-prefixed entries
      shouldInclude =
        name: !(lib.hasPrefix "_" name) && filterf (toString root + "/" + name) && !hasConflict name;

      # Check if a .d directory has valid .nix fragments
      hasValidFragments =
        path:
        let
          fragEntries = builtins.readDir path;
          fragNames = builtins.attrNames fragEntries;
        in
        builtins.any (
          name:
          let
            type = fragEntries.${name};
          in
          if type == "regular" then
            lib.hasSuffix ".nix" name && !(lib.hasPrefix "_" name)
          else if type == "directory" then
            builtins.pathExists (path + "/${name}/default.nix") && !(lib.hasPrefix "_" name)
          else
            false
        ) fragNames;

      # Process a .d fragment directory: import all .nix files and merge as attrsets
      processFragmentDir =
        path:
        let
          fragEntries = builtins.readDir path;
          fragNames = lib.sort (a: b: a < b) (builtins.attrNames fragEntries);

          isValidFragment =
            name:
            let
              type = fragEntries.${name};
            in
            if type == "regular" then
              lib.hasSuffix ".nix" name && !(lib.hasPrefix "_" name)
            else if type == "directory" then
              builtins.pathExists (path + "/${name}/default.nix") && !(lib.hasPrefix "_" name)
            else
              false;

          validNames = builtins.filter isValidFragment fragNames;

          loadFragment =
            name:
            let
              fragPath = path + "/${name}";
            in
            treef fragPath;

          fragments = map loadFragment validNames;
        in
        lib.foldl' lib.recursiveUpdate { } fragments;

      processEntry =
        name: type:
        let
          path = root + "/${name}";
          attrName = toAttrName name;
          isFragmentDir = lib.hasSuffix ".d" name;
        in
        if type == "regular" && lib.hasSuffix ".nix" name then
          let
            # Check for conflicting .d directory
            dDir = (lib.removeSuffix ".nix" name) + ".d";
          in
          if entries ? ${dDir} then
            throw "imp.tree: conflict at ${toString root} - both ${name} and ${dDir} exist. Use one or the other."
          else
            { ${attrName} = treef path; }
        else if type == "directory" then
          if isFragmentDir then
            # Only include .d directories that have valid .nix fragments
            if hasValidFragments path then { ${attrName} = processFragmentDir path; } else { }
          else
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
