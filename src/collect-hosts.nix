/**
  Scan directories for `__host` declarations and collect host metadata.

  Recursively walks the given path(s), importing each `.nix` file and extracting
  any `__host` attrset. Returns an attrset mapping host names to their declarations.
  Host names derive from directory names (for `default.nix` files) or filenames
  (for other `.nix` files, minus the extension).

  Files and directories starting with `_` are excluded. If a directory contains
  `default.nix`, that file is processed and recursion stops; subdirectories are
  not scanned.

  # Type

  ```
  collectHosts :: (path | [path]) -> {
    <hostName> = {
      __host = { system, stateVersion, bases?, sinks?, hmSinks?, modules?, user? };
      config = path | null;
      extraConfig = module | null;
      __source = string;  # path to source file
    };
  }
  ```

  # Example

  ```nix
  collectHosts ./registry/hosts
  # => {
  #   desktop = { __host = { system = "x86_64-linux"; ... }; config = ./desktop/config; ... };
  #   server = { __host = { ... }; ... };
  # }
  ```

  # Host Schema

  Each collected host contains the raw `__host` attrset from the file:

  ```nix
  {
    __host = {
      system = "x86_64-linux";      # target architecture
      stateVersion = "24.11";       # NixOS state version
      bases = [ "hosts.shared.base" ];  # registry paths to base config trees
      sinks = [ "shared.nixos" ];   # export sink paths for NixOS modules
      hmSinks = [ "shared.hm" ];    # export sink paths for Home Manager
      modules = [ "mod.nixos.ssh" "@foo.nixosModules.bar" ];  # extra modules
      user = "alice";               # username for HM integration (null = disabled)
    };
    config = ./config;              # host-specific config tree path
    extraConfig = { modulesPath, ... }: { };  # module with access to modulesPath
  }
  ```

  Modules in the `modules` list resolve as:
  - Plain strings: registry paths (`"mod.nixos.ssh"` -> `registry.mod.nixos.ssh`)
  - `@`-prefixed strings: input paths (`"@foo.bar"` -> `inputs.foo.bar`)
  - Functions/attrsets: passed through unchanged
*/
let
  # Check if path should be excluded (starts with `_` in basename)
  isExcluded =
    path:
    let
      str = toString path;
      parts = builtins.filter builtins.isString (builtins.split "/" str);
      nonEmpty = builtins.filter (x: x != "") parts;
      basename = builtins.elemAt nonEmpty (builtins.length nonEmpty - 1);
    in
    builtins.substring 0 1 basename == "_";

  # Get host name from path (directory name or file basename without .nix)
  getHostName =
    path:
    let
      str = toString path;
      parts = builtins.filter builtins.isString (builtins.split "/" str);
      nonEmpty = builtins.filter (x: x != "") parts;
      last = builtins.elemAt nonEmpty (builtins.length nonEmpty - 1);
      # If it's default.nix, use parent dir name
      isDefault = last == "default.nix";
      name =
        if isDefault then
          builtins.elemAt nonEmpty (builtins.length nonEmpty - 2)
        else
          builtins.replaceStrings [ ".nix" ] [ "" ] last;
    in
    name;

  isAttrs = builtins.isAttrs;
  isFunction = builtins.isFunction;

  # Safely extract `__host` from imported value
  safeExtractHost =
    value:
    let
      hasIt = builtins.tryEval (isAttrs value && value ? __host && isAttrs value.__host);
    in
    if hasIt.success && hasIt.value then
      let
        host = value.__host;
        forced = builtins.tryEval (builtins.deepSeq host host);
      in
      if forced.success then
        {
          __host = forced.value;
          config = value.config or null;
          extraConfig = value.extraConfig or null;
        }
      else
        null
    else
      null;

  # Import a `.nix` file and extract `__host`
  importAndExtract =
    path:
    let
      imported = builtins.tryEval (import path);
    in
    if !imported.success then
      null
    else if isAttrs imported.value then
      safeExtractHost imported.value
    else
      null;

  # Process a single `.nix` file
  processFile =
    acc: path:
    let
      extracted = importAndExtract path;
      hostName = getHostName path;
    in
    if extracted == null then
      acc
    else
      acc
      // {
        ${hostName} = extracted // {
          __source = toString path;
        };
      };

  # Process a directory recursively
  processDir =
    acc: path:
    let
      entries = builtins.readDir path;
      names = builtins.attrNames entries;

      process =
        acc: name:
        let
          entryPath = path + "/${name}";
          entryType = entries.${name};
          resolvedType = if entryType == "symlink" then builtins.readFileType entryPath else entryType;
        in
        if isExcluded entryPath then
          acc
        else if resolvedType == "regular" && builtins.match ".*\\.nix" name != null then
          processFile acc entryPath
        else if resolvedType == "directory" then
          let
            defaultPath = entryPath + "/default.nix";
            hasDefault = builtins.pathExists defaultPath;
          in
          if hasDefault then processFile acc defaultPath else processDir acc entryPath
        else
          acc;
    in
    builtins.foldl' process acc names;

  # Process a path (file or directory)
  processPath =
    acc: path:
    let
      rawPathType = builtins.readFileType path;
      pathType = if rawPathType == "symlink" then builtins.readFileType path else rawPathType;
    in
    if pathType == "regular" then
      processFile acc path
    else if pathType == "directory" then
      processDir acc path
    else
      acc;

  # Main: accepts path or list of paths
  collectHosts =
    pathOrPaths:
    let
      paths = if builtins.isList pathOrPaths then pathOrPaths else [ pathOrPaths ];
      result = builtins.foldl' processPath { } paths;
    in
    result;

in
collectHosts
