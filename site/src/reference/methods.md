# API Methods

<!-- Auto-generated from src/api.nix - do not edit -->

## `imp.filter` {#imp.filter}

Filter paths by predicate. Multiple filters compose with AND.

### Example

```nix
imp.filter (lib.hasInfix "/services/") ./modules
imp.filterNot (lib.hasInfix "/deprecated/") ./modules
```

### Arguments

predicate
: Function that receives a path string and returns boolean.

## `imp.filterNot` {#imp.filterNot}

Exclude paths matching predicate. Opposite of filter.

### Example

```nix
imp.filterNot (lib.hasInfix "/deprecated/") ./modules
```

### Arguments

predicate
: Function that receives a path string and returns boolean.

## `imp.match` {#imp.match}

Filter paths by regex. Uses builtins.match.

### Example

```nix
imp.match ".*[/]services[/].*" ./nix
```

### Arguments

regex
: Regular expression string.

## `imp.matchNot` {#imp.matchNot}

Exclude paths matching regex. Opposite of match.

### Example

```nix
imp.matchNot ".*[/]test[/].*" ./src
```

### Arguments

regex
: Regular expression string.

## `imp.initFilter` {#imp.initFilter}

Replace the default filter. By default, imp finds .nix files
and excludes paths containing underscore prefixes.

### Example

```nix
# Import markdown files instead of nix files
imp.initFilter (lib.hasSuffix ".md") ./docs
```

### Arguments

predicate
: Function that receives a path string and returns boolean.

## `imp.map` {#imp.map}

Transform each matched path. Composes with multiple calls.

### Example

```nix
imp.map import ./packages
```

### Arguments

f
: Transformation function applied to each path or value.

## `imp.mapTree` {#imp.mapTree}

Transform values when building a tree with .tree. Composes with multiple calls.

### Example

```nix
(imp.withLib lib)
  .mapTree (drv: drv // { meta.priority = 5; })
  .tree ./packages
```

### Arguments

f
: Transformation function applied to each tree value.

## `imp.withLib` {#imp.withLib}

Provide nixpkgs lib. Required before using .leafs, .files, .tree, or .configTree.

### Example

```nix
imp.withLib pkgs.lib
imp.withLib inputs.nixpkgs.lib
```

### Arguments

lib
: The nixpkgs lib attribute set.

## `imp.addPath` {#imp.addPath}

Add additional paths to search.

### Example

```nix
(imp.withLib lib)
  .addPath ./modules
  .addPath ./vendor
  .leafs
```

### Arguments

path
: Path to add to the search.

## `imp.addAPI` {#imp.addAPI}

Extend imp with custom methods. Methods receive self for chaining.

### Example

```nix
let
  myImp = imp.addAPI {
    services = self: self.filter (lib.hasInfix "/services/");
    packages = self: self.filter (lib.hasInfix "/packages/");
  };
in
myImp.services ./nix
```

### Arguments

api
: Attribute set of name = self: ... methods.

## `imp.pipeTo` {#imp.pipeTo}

Apply a function to the final file list.

### Example

```nix
(imp.withLib lib).pipeTo builtins.length ./modules
```

### Arguments

f
: Function to apply to the file list.

## `imp.leafs` {#imp.leafs}

Get the list of matched files. Requires .withLib.

### Example

```nix
(imp.withLib lib).leafs ./modules
```

## `imp.tree` {#imp.tree}

Build a nested attrset from directory structure. Requires .withLib.

Directory names become attribute names. Files are imported and their
values placed at the corresponding path.

### Example

```nix
(imp.withLib lib).tree ./outputs
# { packages.hello = <imported>; apps.run = <imported>; }
```

### Arguments

path
: Root directory to build tree from.

## `imp.treeWith` {#imp.treeWith}

Convenience function combining .withLib, .mapTree, and .tree.

### Example

```nix
# These are equivalent:
((imp.withLib lib).mapTree (f: f args)).tree ./outputs
imp.treeWith lib (f: f args) ./outputs
```

### Arguments

lib
: The nixpkgs lib attribute set.

f
: Transformation function for tree values.

path
: Root directory to build tree from.

## `imp.configTree` {#imp.configTree}

Build a module where directory structure maps to NixOS option paths.
Each file receives module args and returns config values.

### Example

```nix
{ inputs, lib, ... }: {
  imports = [ ((inputs.imp.withLib lib).configTree ./config) ];
}
# File ./config/programs/git.nix sets config.programs.git
```

### Arguments

path
: Root directory containing config files.

## `imp.configTreeWith` {#imp.configTreeWith}

Like .configTree but passes extra arguments to each file.

### Example

```nix
(imp.withLib lib).configTreeWith { myArg = "value"; } ./config
```

### Arguments

extraArgs
: Additional arguments passed to each config file.

path
: Root directory containing config files.

## `imp.mergeConfigTrees` {#imp.mergeConfigTrees}

Merge multiple config trees into a single module.

### Example

```nix
# Later trees override earlier (default)
(imp.withLib lib).mergeConfigTrees [ ./base ./overrides ]

# With mkMerge semantics
(imp.withLib lib).mergeConfigTrees { strategy = "merge"; } [ ./base ./local ]
```

### Arguments

options (optional)
: Attribute set with strategy ("override" or "merge") and extraArgs.

paths
: List of directories to merge.

## `imp.new` {#imp.new}

Returns a fresh imp instance with empty state, preserving custom API extensions.

### Example

```nix
let
  customImp = imp.addAPI { myMethod = self: self.filter predicate; };
  fresh = customImp.new;
in
fresh.myMethod ./src
```

## `imp.imports` {#imp.imports}

Build a modules list from mixed items. Handles paths, registry nodes, and modules.

### Example

```nix
modules = imp.imports [
  registry.hosts.server
  registry.modules.nixos.base
  ./local-module.nix
  inputs.home-manager.nixosModules.home-manager
  { services.openssh.enable = true; }
];
```

### Arguments

items
: List of paths, registry nodes, or module values.

## `imp.analyze` {#imp.analyze}

Namespace for dependency analysis and visualization.

### Example

```nix
graph = (imp.withLib lib).analyze.registry { registry = myRegistry; }
html = (imp.withLib lib).analyze.toHtml graph
json = (imp.withLib lib).analyze.toJson graph
```

## Standalone Utilities

These functions work without calling `.withLib` first.

### `imp.registry` {#imp.registry}

Build a registry from a directory structure. Requires `.withLib`.

#### Example

```nix
registry = (imp.withLib lib).registry ./nix
# => { hosts.server = <path>; modules.nixos.base = <path>; ... }
```

### `imp.collectInputs` {#imp.collectInputs}

Scan directories for `__inputs` declarations and collect them.

#### Example

```nix
imp.collectInputs ./outputs
# => { treefmt-nix = { url = "github:numtide/treefmt-nix"; }; }
```

### `imp.formatFlake` {#imp.formatFlake}

Format collected inputs as a flake.nix string.

#### Example

```nix
imp.formatFlake {
  description = "My flake";
  coreInputs = { nixpkgs.url = "github:nixos/nixpkgs"; };
  collectedInputs = imp.collectInputs ./outputs;
}
```

### `imp.collectAndFormatFlake` {#imp.collectAndFormatFlake}

Convenience function combining collectInputs and formatFlake.

#### Example

```nix
imp.collectAndFormatFlake {
  src = ./outputs;
  coreInputs = { nixpkgs.url = "github:nixos/nixpkgs"; };
  description = "My flake";
}
```
