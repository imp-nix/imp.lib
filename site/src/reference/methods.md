# API Methods

All chainable methods available on the `imp` object.

## Core Methods

### `imp <path>`

Import a directory as a NixOS/Home Manager module.

```nix
{ inputs, ... }:
{
  imports = [ (inputs.imp ./modules) ];
}
```

### `.withLib <lib>`

Bind nixpkgs lib for methods that need it. Required for most operations.

```nix
let
  imp = inputs.imp.withLib lib;
in
{
  imports = [ (imp ./modules) ];
}
```

### `.imports <list>`

Handle mixed content - paths are imported, modules/attrsets pass through.

```nix
modules = imp.imports [
  registry.hosts.server          # path -> imported
  inputs.disko.nixosModules.foo  # module -> passed through
  { services.ssh.enable = true; } # attrset -> passed through
];
```

## Filtering Methods

### `.filter <predicate>`

Filter paths by predicate function.

```nix
# Only files containing "/services/"
imp.filter (lib.hasInfix "/services/") ./modules

# Multiple conditions
imp.filter (p: 
  lib.hasInfix "/server/" p && 
  !lib.hasSuffix ".test.nix" p
) ./modules
```

### `.filterNot <predicate>`

Exclude paths matching predicate.

```nix
# Exclude test files
imp.filterNot (lib.hasSuffix ".test.nix") ./modules

# Exclude config directories
imp.filterNot (lib.hasInfix "/config/") ./modules
```

### `.match <regex>`

Filter paths by regex pattern.

```nix
# Only user or group modules
imp.match ".*/users/.*|.*/groups/.*" ./modules
```

## Transformation Methods

### `.map <function>`

Transform matched paths.

```nix
# Import each file
imp.map import ./modules

# Apply custom processing
imp.map (path: import path { inherit lib; }) ./modules
```

## Tree Methods

### `.tree <path>`

Build nested attrset from directory structure.

```nix
imp.tree ./outputs
# Given: outputs/packages/foo.nix, outputs/apps.nix
# Returns: { packages = { foo = <...>; }; apps = <...>; }
```

### `.treeWith <lib> <transform> <path>`

Tree with custom transform function.

```nix
imp.treeWith lib import ./outputs
# Same structure, but each file is imported
```

### `.leafs <path>`

Get list of matched file paths.

```nix
imp.leafs ./modules
# => [ "/path/to/modules/foo.nix" "/path/to/modules/bar.nix" ... ]
```

## Config Tree Methods

### `.configTree <path>`

Map directory structure to option paths.

```nix
# programs/git.nix -> programs.git = { ... }
imp.configTree ./home
```

With options:

```nix
imp.configTree {
  extraArgs = { myVar = "value"; };
} ./home
```

### `.mergeConfigTrees <list>`

Merge multiple config trees.

```nix
# Default: override strategy
imp.mergeConfigTrees [ ./base ./extended ]

# With merge strategy
imp.mergeConfigTrees { strategy = "merge"; } [
  ./base
  ./extended
]
```

## Registry Methods

### `.registry <path>`

Build a named module registry from directory.

```nix
imp.registry ./registry
# Returns: { hosts = { server = <path>; }; modules = { ... }; }
```

### `.collectInputs <path>`

Collect `__inputs` declarations from directory.

```nix
imp.collectInputs ./outputs
# Returns: { treefmt-nix = { url = "..."; }; ... }
```

## Extension Methods

### `.addAPI <attrset>`

Extend imp with custom methods.

```nix
let
  imp = inputs.imp.addAPI {
    myFilter = self: pred: path:
      self.filter pred path;
  };
in
imp.myFilter (lib.hasInfix "/custom/") ./modules
```

## Method Chaining

Methods can be chained:

```nix
let
  imp = inputs.imp.withLib lib;
in
imp
  .filter (lib.hasInfix "/server/")
  .filterNot (lib.hasSuffix ".test.nix")
  .match ".*\\.nix$"
  ./modules
```

## Type Signatures

```
imp : path -> module
.withLib : lib -> imp
.imports : list -> list
.filter : (string -> bool) -> path -> module
.filterNot : (string -> bool) -> path -> module
.match : string -> path -> module
.map : (path -> a) -> path -> [a]
.tree : path -> attrset
.treeWith : lib -> (path -> a) -> path -> attrset
.configTree : path | { extraArgs? } -> path -> module
.mergeConfigTrees : list | { strategy?, extraArgs? } -> list -> module
.leafs : path -> [path]
.registry : path -> attrset
.collectInputs : path -> attrset
.addAPI : attrset -> imp
```

## See Also

- [Module Options](./options.md) - flake-parts configuration options
- [File Reference](./files.md) - Source file documentation
