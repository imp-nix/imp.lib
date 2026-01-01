/**
  Fragment collection and composition for `.d` directories.

  Follows the `.d` convention (like conf.d, init.d) where:
  - `foo.d/` contains fragments that compose into `foo`
  - Fragments are sorted by filename for deterministic ordering
  - Composition strategy depends on content type

  # Supported patterns

  String concatenation (shellHook.d/, prelude.d/):
    shellHook.d/
      00-base.sh
      10-lintfra.sh
      20-rust.sh
    -> concatenated in order

  List merging (packages.d/):
    packages.d/
      base.nix      # returns [ pkgs.git pkgs.curl ]
      lintfra.nix   # returns [ pkgs.ast-grep ]
    -> merged into single list

  Attrset merging (env.d/):
    env.d/
      base.nix      # returns { FOO = "bar"; }
      extra.nix     # returns { BAZ = "qux"; }
    -> merged into single attrset

  # Usage

  ```nix
  let
    fragments = imp.collectFragments ./shellHook.d;
  in
  pkgs.mkShell {
    shellHook = fragments.asString;
    # or: shellHook = lib.concatStringsSep "\n" fragments.list;
  }
  ```
*/
{
  lib,
}:
let
  /**
    Collect fragments from a .d directory.

    # Arguments

    - `dir` (path): Directory ending in .d containing fragments

    # Returns

    Attrset with:
    - `list`: List of fragment contents in sorted order
    - `asString`: Fragments concatenated with newlines
    - `asList`: Fragments flattened (for lists of lists)
    - `asAttrs`: Fragments merged (for attrsets)
  */
  collectFragments =
    dir:
    let
      entries = builtins.readDir dir;

      # Sort by filename for deterministic ordering
      sortedNames = lib.sort (a: b: a < b) (builtins.attrNames entries);

      # Import each fragment
      importFragment =
        name:
        let
          path = dir + "/${name}";
          type = entries.${name};
        in
        if type == "regular" then
          import path
        else if type == "directory" && builtins.pathExists (path + "/default.nix") then
          import path
        else
          null;

      # Filter out nulls and non-.nix files for regular files
      isValidFragment =
        name:
        let
          type = entries.${name};
        in
        if type == "regular" then
          lib.hasSuffix ".nix" name || lib.hasSuffix ".sh" name
        else if type == "directory" then
          builtins.pathExists (dir + "/${name}/default.nix")
        else
          false;

      validNames = builtins.filter isValidFragment sortedNames;

      # For .sh files, read content directly; for .nix, import
      loadFragment =
        name:
        let
          path = dir + "/${name}";
        in
        if lib.hasSuffix ".sh" name then
          builtins.readFile path
        else
          import path;

      fragments = map loadFragment validNames;
    in
    {
      # Raw list of fragments
      list = fragments;

      # Concatenate as string (for shellHook, etc.)
      asString = lib.concatStringsSep "\n" (
        map (f: if builtins.isString f then f else builtins.toString f) fragments
      );

      # Flatten lists (for packages.d where each file returns a list)
      asList = lib.flatten fragments;

      # Merge attrsets (for env.d, etc.)
      asAttrs = lib.foldl' (acc: f: acc // f) { } (builtins.filter builtins.isAttrs fragments);
    };

  /**
    Collect fragments with arguments passed to each .nix file.

    # Arguments

    - `args` (attrset): Arguments to pass to each fragment function
    - `dir` (path): Directory containing fragments

    # Returns

    Same as collectFragments but each .nix fragment is called with args.
  */
  collectFragmentsWith =
    args: dir:
    let
      entries = builtins.readDir dir;
      sortedNames = lib.sort (a: b: a < b) (builtins.attrNames entries);

      isValidFragment =
        name:
        let
          type = entries.${name};
        in
        if type == "regular" then
          lib.hasSuffix ".nix" name || lib.hasSuffix ".sh" name
        else if type == "directory" then
          builtins.pathExists (dir + "/${name}/default.nix")
        else
          false;

      validNames = builtins.filter isValidFragment sortedNames;

      loadFragment =
        name:
        let
          path = dir + "/${name}";
          imported = import path;
        in
        if lib.hasSuffix ".sh" name then
          builtins.readFile path
        else if builtins.isFunction imported then
          imported args
        else
          imported;

      fragments = map loadFragment validNames;
    in
    {
      list = fragments;
      asString = lib.concatStringsSep "\n" (
        map (f: if builtins.isString f then f else builtins.toString f) fragments
      );
      asList = lib.flatten fragments;
      asAttrs = lib.foldl' (acc: f: acc // f) { } (builtins.filter builtins.isAttrs fragments);
    };

in
{
  inherit collectFragments collectFragmentsWith;
}
