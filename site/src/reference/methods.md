# API Methods

## Core

### `imp <path>`

Import directory as module.

### `.withLib <lib>`

Bind nixpkgs lib (required for most operations).

### `.imports <list>`

Handle mixed content - paths are imported, modules/attrsets pass through:

```nix
modules = imp.imports [
  registry.hosts.server
  inputs.disko.nixosModules.foo
  { services.ssh.enable = true; }
];
```

## Filtering

### `.filter <predicate>`

```nix
imp.filter (lib.hasInfix "/services/") ./modules
```

### `.filterNot <predicate>`

```nix
imp.filterNot (lib.hasSuffix ".test.nix") ./modules
```

### `.match <regex>`

```nix
imp.match ".*/users/.*" ./modules
```

## Transformation

### `.map <function>`

```nix
imp.map import ./modules
imp.map (path: import path { inherit lib; }) ./modules
```

## Tree

### `.tree <path>`

```nix
imp.tree ./outputs
# => { packages = { foo = <...>; }; apps = <...>; }
```

### `.treeWith <lib> <transform> <path>`

```nix
imp.treeWith lib import ./outputs
```

### `.leafs <path>`

```nix
imp.leafs ./modules
# => [ "/path/to/modules/foo.nix" ... ]
```

## Config Tree

### `.configTree <path>`

```nix
imp.configTree ./home
imp.configTree { extraArgs = { myVar = "value"; }; } ./home
```

### `.mergeConfigTrees <list>`

```nix
imp.mergeConfigTrees [ ./base ./extended ]
imp.mergeConfigTrees { strategy = "merge"; } [ ./base ./extended ]
```

## Registry

### `.registry <path>`

```nix
imp.registry ./registry
# => { hosts = { server = <path>; }; ... }
```

### `.collectInputs <path>`

```nix
imp.collectInputs ./outputs
# => { treefmt-nix = { url = "..."; }; }
```

## Extension

### `.addAPI <attrset>`

```nix
let imp = inputs.imp.addAPI {
  myFilter = self: pred: path: self.filter pred path;
}; in
imp.myFilter (lib.hasInfix "/custom/") ./modules
```

## Chaining

```nix
imp
  .filter (lib.hasInfix "/server/")
  .filterNot (lib.hasSuffix ".test.nix")
  ./modules
```

## Type signatures

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
