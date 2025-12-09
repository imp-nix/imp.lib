/**
  Collects __exports declarations from directory trees.
  Standalone implementation - no nixpkgs dependency, only builtins.

  Scans `.nix` files recursively for `__exports` attribute declarations and
  collects them, tracking source paths for debugging and conflict detection.

  Handles two patterns:
  1. Static exports: attrsets with __exports at top level
  2. Functor exports: attrsets with __functor that returns __exports when called

  For functors, the functor is called with empty args to extract exports.
  The actual values are lazy (Nix thunks) so inputs etc. aren't evaluated
  until the module is actually used.

  # Example

  ```nix
  # Static pattern
  {
    __exports."sink.name".value = { config = ...; };
    __module = ...;
  }

  # Functor pattern (for modules needing inputs)
  {
    __inputs = { foo.url = "..."; };
    __functor = _: { inputs, ... }:
      let mod = { ... };
      in { __exports."sink.name".value = mod; __module = mod; };
  }
  ```

  # Arguments

  pathOrPaths
  : Directory/file path, or list of paths, to scan for __exports declarations.
*/
let
  # Check if path should be excluded (starts with `_` in basename)
  isExcluded =
    path:
    let
      str = toString path;
      parts = builtins.filter (x: x != "") (builtins.split "/" str);
      basename = builtins.elemAt parts (builtins.length parts - 1);
    in
    builtins.substring 0 1 basename == "_";

  isAttrs = builtins.isAttrs;
  isFunction = builtins.isFunction;

  # Safely extract `__exports`, catching evaluation errors with `tryEval`
  safeExtractExports =
    value:
    let
      hasIt = builtins.tryEval (isAttrs value && value ? __exports && isAttrs value.__exports);
    in
    if hasIt.success && hasIt.value then
      let
        exports = value.__exports;
        forced = builtins.tryEval (builtins.deepSeq exports exports);
      in
      if forced.success then forced.value else { }
    else
      { };

  # Try to call a functor and extract exports from the result
  # For functors needing inputs, we pass a stub - values are lazy thunks
  # We use tryEval heavily because calling the functor may fail for modules
  # that depend on specific input values
  tryFunctorExports =
    value:
    if isAttrs value && value ? __functor then
      let
        # Call outer functor (typically _: innerFn)
        innerFn = builtins.tryEval (value.__functor value);
      in
      if innerFn.success && isFunction innerFn.value then
        let
          # Check what args the inner function needs
          innerArgs = builtins.tryEval (builtins.functionArgs innerFn.value);
        in
        if innerArgs.success then
          let
            # Build stub args - empty attrsets for required params
            stubArgs = builtins.mapAttrs (name: hasDefault: if hasDefault then null else { }) innerArgs.value;
            # Call inner function with stubs, wrapped in tryEval
            result = builtins.tryEval (innerFn.value stubArgs);
          in
          if result.success && isAttrs result.value then safeExtractExports result.value else { }
        else
          { }
      else if innerFn.success && isAttrs innerFn.value then
        # Functor returned an attrset directly
        safeExtractExports innerFn.value
      else
        { }
    else
      { };

  # Import a `.nix` file and extract `__exports` from attrsets
  # Handles both static exports and functor patterns
  importAndExtract =
    path:
    let
      imported = builtins.tryEval (import path);
    in
    if !imported.success then
      { }
    else if isAttrs imported.value then
      let
        # Try static exports first
        staticExports = safeExtractExports imported.value;
        # If none, try functor pattern
        functorExports = if staticExports == { } then tryFunctorExports imported.value else { };
      in
      if staticExports != { } then staticExports else functorExports
    else
      # Plain functions without __functor are not supported
      { };

  # Normalize export entry: ensure it has value and optional strategy
  normalizeExportEntry =
    sinkKey: entry:
    if isAttrs entry && entry ? value then
      {
        value = entry.value;
        strategy = entry.strategy or null;
      }
    else
      # If just a raw value, wrap it
      {
        value = entry;
        strategy = null;
      };

  # Process exports from a single file
  processFileExports =
    sourcePath: exports:
    let
      sinkKeys = builtins.attrNames exports;
    in
    builtins.foldl' (
      acc: sinkKey:
      let
        entry = normalizeExportEntry sinkKey exports.${sinkKey};
        exportRecord = {
          source = toString sourcePath;
          inherit (entry) value strategy;
        };
      in
      acc
      // {
        ${sinkKey} = if acc ? ${sinkKey} then acc.${sinkKey} ++ [ exportRecord ] else [ exportRecord ];
      }
    ) { } sinkKeys;

  # Merge exports from multiple files
  mergeExports =
    acc: newExports:
    let
      allKeys = builtins.attrNames acc ++ builtins.attrNames newExports;
      uniqueKeys = builtins.foldl' (
        keys: key: if builtins.elem key keys then keys else keys ++ [ key ]
      ) [ ] allKeys;
    in
    builtins.foldl' (
      result: key:
      result
      // {
        ${key} = (acc.${key} or [ ]) ++ (newExports.${key} or [ ]);
      }
    ) { } uniqueKeys;

  # Process a single `.nix` file
  processFile =
    acc: path:
    let
      exports = importAndExtract path;
    in
    if exports == { } then acc else mergeExports acc (processFileExports path exports);

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
  collectExports =
    pathOrPaths:
    let
      paths = if builtins.isList pathOrPaths then pathOrPaths else [ pathOrPaths ];
      result = builtins.foldl' processPath { } paths;
    in
    result;

in
collectExports
