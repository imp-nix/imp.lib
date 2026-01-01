# File Reference

<!-- Auto-generated - do not edit -->

## Core

### default.nix

Entry point for imp - directory-based Nix imports.

This module exports the main imp API including:

- Chainable filtering and transformation methods
- Tree building from directory structure
- Registry for named module discovery
- Utilities for flake input collection

### api.nix

API method definitions for imp.

This module defines all chainable methods available on the imp object.
Methods are organized into categories:

- Filtering: `filter`, `filterNot`, `match`, `matchNot`, `initFilter`
- Transforming: `map`, `mapTree`
- Tree building: `tree`, `treeWith`, `configTree`, `configTreeWith`
- Fragments: `fragments`, `fragmentsWith`
- File lists: `leafs`, `files`, `pipeTo`
- Extending: `addPath`, `addAPI`, `withLib`, `new`

### lib.nix

Internal utility functions for imp.

## Import & Collection

### collect.nix

File collection and filtering logic.

This module handles:

- Recursive file discovery from paths
- Filter composition and application
- Path normalization (absolute to relative)

### tree.nix

Builds nested attrset from directory structure.

Naming: `foo.nix` | `foo/default.nix` -> `{ foo = ... }`
`foo_.nix` -> `{ foo = ... }` (escapes reserved names)
`_foo.nix` | `_foo/` -> ignored
`foo.d/` -> fragment directory (merged attrsets)

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

#### Example

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

#### Usage

```nix
(imp.withLib lib).tree ./outputs
```

Or with transform:

```nix
((imp.withLib lib).mapTree (f: f args)).tree ./outputs
imp.treeWith lib (f: f args) ./outputs
```

## Config Trees

### configTree.nix

Builds a NixOS/Home Manager module where directory structure = option paths.

Each file receives module args (`{ config, lib, pkgs, ... }`) plus `extraArgs`,
and returns config values. The path becomes the option path:

- `programs/git.nix` -> `{ programs.git = <result>; }`
- `services/nginx/default.nix` -> `{ services.nginx = <result>; }`

#### Example

Directory structure:

```
home/
  programs/
    git.nix
    zsh.nix
  services/
    syncthing.nix
```

Example file (home/programs/git.nix):

```nix
{ pkgs, ... }: {
  enable = true;
  userName = "Alice";
}
```

#### Usage

```nix
{ inputs, ... }:
{
  imports = [ ((inputs.imp.withLib lib).configTree ./home) ];
}
```

Equivalent to manually writing:

```nix
programs.git = { enable = true; userName = "Alice"; };
programs.zsh = { ... };
services.syncthing = { ... };
```

With extra args:

```nix
((inputs.imp.withLib lib).configTreeWith { myArg = "value"; } ./home)
```

### mergeConfigTrees.nix

Merges multiple config trees into a single NixOS/Home Manager module.

Supports two merge strategies:

- `override` (default): Later trees override earlier (`lib.recursiveUpdate`)
- `merge`: Use module system's `mkMerge` for proper option merging

This enables composable features where one extends another:

```
features/
  shell/programs/{zsh,starship}.nix    # base shell config
  devShell/programs/{git,zsh}.nix      # extends shell, overrides zsh
```

#### Usage

Override strategy (default):

```nix
# devShell/default.nix
{ imp, ... }:
{
  imports = [
    (imp.mergeConfigTrees [ ../shell ./. ])
  ];
}
```

Or with merge strategy for concatenating list options:

```nix
{ imp, ... }:
{
  imports = [
    (imp.mergeConfigTrees { strategy = "merge"; } [ ../shell ./. ])
  ];
}
```

With `override`: later values completely replace earlier ones.
With `merge`: options combine according to module system rules:

- lists concatenate
- strings may error (use `mkForce`/`mkDefault` to control)
- nested attrs merge recursively

## Registry

### registry.nix

Registry: named module discovery and resolution.

Scans a directory tree and builds a nested attrset mapping names to paths.
Files reference modules by name instead of relative paths.

#### Example

```
nix/
  home/
    alice/default.nix
    bob.nix
  modules/
    nixos/base.nix
    home/base.nix
```

Produces:

```nix
{
  home = {
    __path = <nix/home>;
    alice = <path>;
    bob = <path>;
  };
  modules.nixos = { __path = <nix/modules/nixos>; base = <path>; };
}
```

Usage:

```nix
{ registry, ... }:
{
  imports = [ (imp registry.modules.nixos) ];  # directory
  imports = [ registry.modules.home.base ];    # file
}
```

Directories have `__path` so they work with `imp`.

### analyze.nix

Dependency graph analysis for imp.

Provides functions to analyze config trees and registries, extracting
dependency relationships for visualization.

#### Example

Graph structure:

```nix
{
  nodes = [
    { id = "modules.home.features.shell"; path = /path/to/shell; type = "configTree"; }
    { id = "modules.home.features.devShell"; path = /path/to/devShell; type = "configTree"; }
  ];
  edges = [
    { from = "modules.home.features.devShell"; to = "modules.home.features.shell"; type = "merge"; strategy = "merge"; }
    { from = "modules.home.features.devShell"; to = "modules.home.features.devTools"; type = "merge"; strategy = "merge"; }
  ];
}
```

Usage:

```nix
# Analyze a registry to find all relationships
imp.analyze.registry registry
```

### visualize/default.nix

Visualization output for dependency graphs.

## Export Sinks

### collect-exports.nix

Collects `__exports` declarations from directory trees.

Recursively scans `.nix` files for `__exports` attributes and collects them
with source paths for debugging and conflict detection. No nixpkgs dependency.

Static exports sit at the top level. Functor exports (`__functor`) are called
with stub args to extract declarations; values remain lazy thunks until use.

#### Export Syntax

Both flat string keys and nested attribute paths work:

```nix
# Flat string keys
{ __exports."sink.name".value = { config = ...; }; }

# Nested paths (enables static analysis by tools like imp-refactor)
{ __exports.sink.name.value = { config = ...; }; }

# Functor pattern for modules needing inputs
{
  __inputs = { foo.url = "..."; };
  __functor = _: { inputs, ... }:
    let mod = { ... };
    in { __exports.sink.name.value = mod; __module = mod; };
}
```

#### Arguments

pathOrPaths
: Directory, file, or list of paths to scan.

### export-sinks.nix

Materializes sinks from collected exports by applying merge strategies.

Takes `collectExports` output and produces usable Nix values (modules or
attrsets) by merging contributions according to their strategies.

#### Merge Strategies

- `merge`: Deep merge via `lib.recursiveUpdate` (last wins for primitives)
- `override`: Last writer completely replaces earlier values
- `list-append`: Concatenate lists (errors on non-lists)
- `mkMerge`: Module functions become `{ imports = [...]; }`;
  plain attrsets use `lib.mkMerge`

#### Example

```nix
buildExportSinks {
  lib = nixpkgs.lib;
  collected = {
    "nixos.role.desktop" = [
      { source = "/audio.nix"; value = { services.pipewire.enable = true; }; strategy = "merge"; }
      { source = "/wayland.nix"; value = { services.greetd.enable = true; }; strategy = "merge"; }
    ];
  };
  sinkDefaults = { "nixos.*" = "merge"; };
}
# => { nixos.role.desktop = { __module = { ... }; __meta = { ... }; }; }
```

#### Arguments

lib : nixpkgs lib for merge operations.
collected : Output from `collectExports`.
sinkDefaults : Glob patterns to default strategies (e.g., `{ "nixos.*" = "merge"; }`).
enableDebug : Include `__meta` with contributor info (default: true).

## Flake Integration

### flakeModule.nix

flake-parts module, defines `imp.*` options.

### collect-inputs.nix

`__inputs` collection from flake inputs.

### format-flake.nix

Formats flake inputs and generates flake.nix content.
Standalone implementation - no nixpkgs dependency, only builtins.

#### Example

```nix
formatInputs { treefmt-nix = { url = "..."; }; }
# => "treefmt-nix = {\n  url = \"...\";\n};\n"

formatFlake {
  description = "My flake";
  coreInputs = { nixpkgs.url = "..."; };
  collectedInputs = { treefmt-nix.url = "..."; };
  outputsFile = "./outputs.nix";
}
# => full flake.nix content as string
```
