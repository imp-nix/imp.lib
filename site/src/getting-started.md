# Getting Started

This guide walks you through setting up Imp in your flake.

## Installation

Add `imp` to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    imp.url = "github:Alb-O/imp";
  };
}
```

## Basic Setup

### Option 1: With flake-parts (Recommended)

Imp provides a flake-parts module that auto-loads outputs from a directory:

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

Create your outputs directory:

```
outputs/
  perSystem/
    packages.nix      # -> perSystem.packages
    devShells.nix     # -> perSystem.devShells
  nixosConfigurations/
    server.nix        # -> flake.nixosConfigurations.server
  overlays.nix        # -> flake.overlays
```

### Option 2: As a Module Importer

Use Imp directly to import a directory as a NixOS/Home Manager module:

```nix
{ inputs, ... }:
{
  imports = [ (inputs.imp ./nix) ];
}
```

### Option 3: As a Tree Builder

Build a nested attribute set from a directory:

```nix
# Given outputs/ containing apps.nix and packages/foo.nix
imp.treeWith lib import ./outputs
# => { apps = <...>; packages = { foo = <...>; }; }
```

## What Gets Passed to Files

### In `perSystem/` directory

Files receive:
- `pkgs` - nixpkgs for the current system
- `lib` - nixpkgs lib
- `system` - current system (e.g., "x86_64-linux")
- `self` - the flake
- `self'` - perSystem config for current system
- `inputs` - flake inputs
- `inputs'` - perSystem-ified inputs
- `registry` - the module registry (if configured)

### Outside `perSystem/`

Files receive:
- `lib` - nixpkgs lib
- `self` - the flake
- `inputs` - flake inputs
- `registry` - the module registry (if configured)

## Next Steps

- Learn about [naming conventions](./concepts/naming-conventions.md)
- Set up a [registry](./concepts/registry.md) for named module access
- Use [config trees](./guides/config-trees.md) for option-based configuration
