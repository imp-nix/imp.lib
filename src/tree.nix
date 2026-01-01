/**
  Builds nested attrset from directory structure.

  Naming:  `foo.nix` | `foo/default.nix` -> `{ foo = ... }`
           `foo_.nix`                  -> `{ foo = ... }`  (escapes reserved names)
           `_foo.nix` | `_foo/`          -> ignored
           `foo.d/`                      -> fragment directory (merged attrsets)

  Fragment directories (`*.d/`):
    Only `.d` directories matching known flake output names are auto-merged:
    packages, devShells, checks, apps, overlays, nixosModules, homeModules,
    nixosConfigurations, darwinConfigurations, legacyPackages.

    Other `.d` directories (e.g., shellHook.d) are ignored by tree and should
    be consumed via `imp.fragments` or `imp.fragmentsWith`.

    Merged directories have their `.nix` files imported in sorted order
    (00-base.nix before 10-extra.nix) and combined with `lib.recursiveUpdate`.

  Merging with base file:
    If both `foo.nix` and `foo.d/` exist for a mergeable output, they are
    combined: `foo.nix` is imported first, then `foo.d/*.nix` fragments are
    merged on top using `lib.recursiveUpdate`. This allows a base file to
    define core outputs while fragments add or extend them.

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
  # Flake output names that should be auto-merged when using .d pattern
  mergeableOutputs = [
    "packages"
    "devShells"
    "checks"
    "apps"
    "overlays"
    "nixosModules"
    "homeModules"
    "darwinModules"
    "flakeModules"
    "nixosConfigurations"
    "darwinConfigurations"
    "homeConfigurations"
    "legacyPackages"
  ];

  buildTree =
    root:
    let
      entries = builtins.readDir root;

      toAttrName =
        name:
        let
          withoutNix = lib.removeSuffix ".nix" name;
          withoutD = lib.removeSuffix ".d" withoutNix;
        in
        lib.removeSuffix "_" withoutD;

      # Check if a .d directory should be auto-merged
      isMergeableFragmentDir =
        name:
        let
          baseName = lib.removeSuffix ".d" name;
        in
        lib.hasSuffix ".d" name && builtins.elem baseName mergeableOutputs;

      shouldInclude =
        name:
        !(lib.hasPrefix "_" name)
        && filterf (toString root + "/" + name)
        && !(lib.hasSuffix ".d" name && !isMergeableFragmentDir name);

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
            # Check for companion .d directory to merge with
            dDir = (lib.removeSuffix ".nix" name) + ".d";
            dDirPath = root + "/${dDir}";
            baseValue = treef path;
          in
          if entries ? ${dDir} && isMergeableFragmentDir dDir then
            # Merge foo.nix with foo.d/*.nix fragments
            let
              fragmentValue = processFragmentDir dDirPath;
            in
            { ${attrName} = lib.recursiveUpdate baseValue fragmentValue; }
          else
            { ${attrName} = baseValue; }
        else if type == "directory" then
          if isFragmentDir then
            # Skip .d directories here if they have a companion .nix file (handled above)
            let
              baseName = lib.removeSuffix ".d" name;
              nixFile = baseName + ".nix";
            in
            if entries ? ${nixFile} then
              { } # Already handled when processing the .nix file
            else if hasValidFragments path then
              { ${attrName} = processFragmentDir path; }
            else
              { }
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
