# imp

A Nix library to recursively import Nix files from directories as NixOS modules or nested attrsets.

## Installation

Add `imp` as a flake input:

```nix
{
  inputs.imp.url = "github:Alb-O/imp";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
}
```

## Quick Start

### As a Module Importer

```nix
{ inputs, ... }:
{
  imports = [ (inputs.imp ./nix) ];
}
```

### With flake-parts

`imp` provides a flake-parts module that auto-loads outputs from a directory:

```nix
{
  outputs = inputs@{ flake-parts, imp, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ imp.flakeModules.default ];

      systems = [ "x86_64-linux" "aarch64-linux" ];

      imp = {
        src = ./outputs;            # Directory to load
        args = { inherit inputs; }; # Extra args for all files
      };
    };
}
```

Directory structure:

```
outputs/
  perSystem/
    packages.nix      -> perSystem.packages (receives pkgs, system, etc.)
    devShells.nix     -> perSystem.devShells
  nixosConfigurations/
    server.nix        -> flake.nixosConfigurations.server
  overlays.nix        -> flake.overlays
```

### As a Tree Builder

```nix
# outputs/
#   apps.nix
#   packages/
#     foo.nix

imp.treeWith lib import ./outputs
# { apps = <...>; packages = { foo = <...>; }; }
```

## Naming Conventions

| Path              | Attribute | Notes                               |
| ----------------- | --------- | ----------------------------------- |
| `foo.nix`         | `foo`     | File as module                      |
| `foo/default.nix` | `foo`     | Directory module                    |
| `foo_.nix`        | `foo`     | Trailing `_` escapes reserved names |
| `_foo.nix`        | (ignored) | Leading `_` = hidden                |

## API

Full API documentation with examples is inline in the source:

| File                                         | Purpose                                         |
| -------------------------------------------- | ----------------------------------------------- |
| [`src/api.nix`](src/api.nix)                 | All chainable methods (filter, map, tree, etc.) |
| [`src/collect.nix`](src/collect.nix)         | File collection & filtering logic               |
| [`src/tree.nix`](src/tree.nix)               | Tree building from directories                  |
| [`src/configTree.nix`](src/configTree.nix)   | NixOS/Home Manager config modules               |
| [`src/flakeModule.nix`](src/flakeModule.nix) | Flake-parts integration module                  |
| [`src/lib.nix`](src/lib.nix)                 | Internal utilities                              |

### Overview

| Method                        | Description                          |
| ----------------------------- | ------------------------------------ |
| `imp <path>`                  | Import directory as NixOS module     |
| `.withLib <lib>`              | Bind nixpkgs lib (required for most) |
| `.filter <pred>`              | Filter paths by predicate            |
| `.match <regex>`              | Filter paths by regex                |
| `.map <fn>`                   | Transform matched paths              |
| `.tree <path>`                | Build nested attrset from directory  |
| `.treeWith <lib> <fn> <path>` | Tree with transform                  |
| `.configTree <path>`          | Directory structure → option paths   |
| `.leafs <path>`               | Get list of matched files            |
| `.addAPI <attrset>`           | Extend with custom methods           |

### flake-parts Module Options

| Option             | Type   | Default     | Description                      |
| ------------------ | ------ | ----------- | -------------------------------- |
| `imp.src`          | path   | null        | Directory containing outputs     |
| `imp.args`         | attrs  | {}          | Extra args passed to all files   |
| `imp.perSystemDir` | string | "perSystem" | Subdirectory name for per-system |

Files in `perSystem/` receive: `{ pkgs, lib, system, self, self', inputs, inputs', ... }`

Files outside `perSystem/` receive: `{ lib, self, inputs, ... }`

## Examples

### Config Tree (Home Manager / NixOS)

Directory structure becomes option paths:

```
home/
  programs/
    git.nix      -> programs.git = { ... }
    zsh.nix      -> programs.zsh = { ... }
```

```nix
{ inputs, ... }:
{
  imports = [ ((inputs.imp.withLib lib).configTree ./home) ];
}
```

### Conditional Loading

```nix
let
  imp = inputs.imp.withLib lib;
in
{
  imports = [
    (if isServer
      then imp.filter (lib.hasInfix "/server/") ./modules
      else imp.filter (lib.hasInfix "/desktop/") ./modules)
  ];
}
```

## Development

```sh
nix run .#tests    # Run unit tests
nix flake check    # Full check
nix fmt            # Format with treefmt
```

## Attribution

- Originally written by @vic as [import-tree](https://github.com/vic/import-tree)
- `.tree` inspired by [flakelight](https://github.com/nix-community/flakelight)

## License

Apache-2.0 - see [LICENSE](LICENSE).
