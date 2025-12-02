# importme

Recursively import Nix files from directories - as NixOS modules or nested attrsets.

## Installation

```nix
{
  inputs.importme.url = "github:Alb-O/importme";
}
```

## Usage Modes

### 1. Module Importer

Use `importme` as a function to create a NixOS/flake-parts module that imports all `.nix` files from a directory:

```nix
{ inputs, ... }:
{
  imports = [ (inputs.importme ./modules) ];
}
```

With flake-parts:

```nix
{
  inputs.importme.url = "github:Alb-O/importme";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; }
    (inputs.importme ./nix);
}
```

### 2. File List Builder

Chain filters and transforms to get a list of files:

```nix
let
  importme = inputs.importme.withLib lib;
in
importme.filter (lib.hasInfix "/services/").leafs ./modules
# Returns: [ ./modules/services/nginx.nix ./modules/services/postgres.nix ... ]
```

### 3. Tree Builder

Build nested attrsets from directory structure - useful for flake outputs:

```nix
# Directory structure:
#   outputs/
#     apps.nix
#     checks.nix
#     packages/
#       foo.nix
#       bar.nix

importme.treeWith lib import ./outputs
# Returns:
# {
#   apps = <imported from apps.nix>;
#   checks = <imported from checks.nix>;
#   packages = {
#     foo = <imported from foo.nix>;
#     bar = <imported from bar.nix>;
#   };
# }
```

## Naming Conventions

| Path              | Attribute | Notes                               |
| ----------------- | --------- | ----------------------------------- |
| `foo.nix`         | `foo`     |                                     |
| `foo/default.nix` | `foo`     | Directory with default.nix          |
| `foo_.nix`        | `foo`     | Trailing `_` escapes reserved names |
| `_foo.nix`        | (ignored) | Leading `_` means hidden            |
| `_foo/`           | (ignored) | Hidden directory                    |

The `_` prefix convention allows you to keep helper files or work-in-progress modules in the same directory without importing them.

## API Reference

### Core

#### `importme <path>`

Import all `.nix` files from a path as a NixOS module.

```nix
{ imports = [ (importme ./modules) ]; }
```

#### `.withLib <lib>`

Required before using `.leafs`, `.files`, `.tree`, or `.treeWith`.

```nix
importme.withLib nixpkgs.lib
```

### Filtering

#### `.filter <predicate>` / `.filterNot <predicate>`

Filter paths by predicate. Multiple filters compose with AND.

```nix
importme.filter (lib.hasInfix "/services/") ./modules
importme.filterNot (lib.hasInfix "/deprecated/") ./modules
```

#### `.match <regex>` / `.matchNot <regex>`

Filter paths by regex (uses `builtins.match`).

```nix
importme.match ".*/[a-z]+@(foo|bar)\.nix" ./nix
```

#### `.initFilter <predicate>`

Replace the default filter. By default, importme finds `.nix` files and excludes paths containing `/_`.

```nix
# Import markdown files instead
importme.initFilter (lib.hasSuffix ".md") ./docs
```

### Transforming

#### `.map <function>`

Transform each matched path.

```nix
importme.map import ./packages
# Returns list of imported values instead of paths
```

#### `.mapTree <function>`

Transform values when using `.tree`. Composes with multiple calls.

```nix
(importme.withLib lib)
  .mapTree (drv: drv // { meta.priority = 5; })
  .tree ./packages
```

### Tree Building

#### `.tree <path>`

Build a nested attrset from directory structure. Requires `.withLib`.

```nix
(importme.withLib lib).tree ./outputs
```

#### `.treeWith <lib> <transform> <path>`

Convenience function combining `.withLib`, `.mapTree`, and `.tree`.

```nix
# These are equivalent:
((importme.withLib lib).mapTree (f: f args)).tree ./outputs
importme.treeWith lib (f: f args) ./outputs
```

Real-world example - loading per-system flake outputs:

```nix
{
  outputs = { self, nixpkgs, importme, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        args = { inherit self pkgs; };
      in
      importme.treeWith nixpkgs.lib (f: f args) ./outputs
    );
}
```

Where each file in `./outputs/` is a function taking `args`:

```nix
# outputs/packages.nix
{ pkgs, ... }: {
  hello = pkgs.hello;
  cowsay = pkgs.cowsay;
}
```

### File Lists

#### `.leafs <path>` / `.files`

Get the list of matched files. Requires `.withLib`.

```nix
(importme.withLib lib).leafs ./modules
# Returns: [ ./modules/foo.nix ./modules/bar.nix ... ]

# Or with pre-configured paths:
importme.withLib lib
  |> (i: i.addPath ./modules)
  |> (i: i.filter (lib.hasInfix "/services/"))
  |> (i: i.files)
```

#### `.pipeTo <function> <path>`

Apply a function to the file list.

```nix
(importme.withLib lib).pipeTo builtins.length ./modules
# Returns: 42
```

### Extending

#### `.addPath <path>`

Add additional paths to search.

```nix
importme
  |> (i: i.addPath ./modules)
  |> (i: i.addPath ./vendor)
  |> (i: i.leafs)
```

#### `.addAPI <attrset>`

Extend importme with custom methods. Methods receive `self` for chaining.

```nix
let
  myImporter = importme.addAPI {
    services = self: self.filter (lib.hasInfix "/services/");
    packages = self: self.filter (lib.hasInfix "/packages/");
  };
in
myImporter.services ./nix
```

#### `.new`

Returns a fresh importme with empty state, preserving custom API.

## Examples

### Organizing NixOS Modules

```
nixos/
  modules/
    services/
      nginx.nix
      postgres.nix
    hardware/
      gpu.nix
    _helpers.nix  # ignored - helper functions
```

```nix
{ imports = [ (importme ./nixos/modules) ]; }
```

### Flake with Per-System Outputs

```
outputs/
  apps.nix
  checks.nix
  devShells.nix
  packages/
    foo.nix
    bar.nix
```

```nix
# flake.nix
{
  outputs = { nixpkgs, importme, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      importme.treeWith nixpkgs.lib (f: f { inherit pkgs; }) ./outputs
    );
}

# outputs/apps.nix
{ pkgs, ... }: {
  hello = { type = "app"; program = "${pkgs.hello}/bin/hello"; };
}

# outputs/packages/foo.nix
{ pkgs, ... }:
pkgs.stdenv.mkDerivation { name = "foo"; /* ... */ }
```

### Conditional Module Loading

```nix
let
  importme = inputs.importme.withLib lib;

  serverModules = importme.filter (lib.hasInfix "/server/") ./modules;
  desktopModules = importme.filter (lib.hasInfix "/desktop/") ./modules;
in
{
  imports = [
    (if isServer then serverModules else desktopModules)
  ];
}
```

## Testing

```sh
nix run .#tests    # Run unit tests
nix flake check    # Full check including formatting
```

## Attribution

- Originally written by @vic as [import-tree](https://github.com/vic/import-tree).
- `.tree` inspired by [flakelight](https://github.com/nix-community/flakelight)'s autoload feature.

## License

Apache-2.0 - see [LICENSE](LICENSE).
