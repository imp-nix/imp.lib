# Using with flake-parts

Imp integrates seamlessly with [flake-parts](https://flake.parts) to auto-load flake outputs from a directory structure.

## Basic Setup

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    imp.url = "github:Alb-O/imp";
  };

  outputs = inputs@{ flake-parts, imp, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ imp.flakeModules.default ];

      systems = [ "x86_64-linux" "aarch64-linux" ];

      imp = {
        src = ./outputs;
        args = { inherit inputs; };
      };
    };
}
```

## Directory Structure

```
outputs/
  perSystem/
    packages.nix      # perSystem.packages
    devShells.nix     # perSystem.devShells
    checks.nix        # perSystem.checks
    apps.nix          # perSystem.apps
  nixosConfigurations/
    server.nix        # flake.nixosConfigurations.server
    workstation.nix   # flake.nixosConfigurations.workstation
  homeConfigurations/
    alice.nix         # flake.homeConfigurations.alice
  overlays.nix        # flake.overlays
  nixosModules.nix    # flake.nixosModules
```

## perSystem Files

Files in `perSystem/` receive special arguments:

```nix
# outputs/perSystem/packages.nix
{ pkgs, lib, system, self, self', inputs, inputs', ... }:
{
  hello = pkgs.hello;
  myApp = pkgs.callPackage ./my-app { };
}
```

Available arguments:
- `pkgs` - nixpkgs for the current system
- `lib` - nixpkgs lib
- `system` - current system string
- `self` - the flake itself
- `self'` - perSystem config for current system
- `inputs` - raw flake inputs
- `inputs'` - perSystem-ified inputs
- `registry` - the module registry (if configured)
- `imp` - the imp library with lib bound

## Non-perSystem Files

Files outside `perSystem/` receive:

```nix
# outputs/nixosConfigurations/server.nix
{ lib, self, inputs, registry, imp, ... }:
lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs registry imp; };
  modules = [ /* ... */ ];
}
```

## Adding a Registry

Enable named module access:

```nix
imp = {
  src = ./outputs;
  registry.src = ./registry;
};
```

Then use `registry` in your outputs:

```nix
# outputs/nixosConfigurations/server.nix
{ lib, inputs, imp, registry, ... }:
lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs imp registry; };
  modules = imp.imports [
    registry.hosts.server
    registry.modules.nixos.base
  ];
}
```

## Custom perSystem Directory

Change the perSystem subdirectory name:

```nix
imp = {
  src = ./nix;
  perSystemDir = "per-system";  # Default: "perSystem"
};
```

## Extra Arguments

Pass additional arguments to all files:

```nix
imp = {
  src = ./outputs;
  args = {
    inherit inputs;
    myLib = import ./lib.nix;
  };
};
```

## Multiple Outputs Directories

Import from multiple directories:

```nix
{
  imports = [ imp.flakeModules.default ];
  
  imp.src = ./outputs;
  
  # Additional imports
  imports = [
    (import ./extra-outputs { inherit inputs; })
  ];
}
```

## Combining with Manual Definitions

Imp-loaded outputs merge with manual definitions:

```nix
flake-parts.lib.mkFlake { inherit inputs; } {
  imports = [ imp.flakeModules.default ];
  
  imp.src = ./outputs;
  
  # These merge with outputs loaded from ./outputs
  perSystem = { pkgs, ... }: {
    packages.manual = pkgs.hello;
  };
  
  flake = {
    templates.default = { /* ... */ };
  };
}
```

## See Also

- [Collect Inputs](./collect-inputs.md) - Declare inputs inline
- [Config Trees](./config-trees.md) - Directory structure as option paths
- [Module Options](../reference/options.md) - All configuration options
