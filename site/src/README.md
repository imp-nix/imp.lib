# Imp

A Nix library for organizing flakes with directory-based imports, named module registries, and automatic input collection.

## What is Imp?

Imp helps you organize large Nix configurations by:

- **Directory-based imports** - Import entire directories as NixOS/Home Manager modules
- **Named registries** - Reference modules by name (`registry.modules.nixos.base`) instead of paths
- **Config trees** - Map directory structure to option paths (`programs/git.nix` → `programs.git = { ... }`)
- **Automatic input collection** - Declare inputs inline where they're used
- **Migration tooling** - Detect and fix broken references when you rename directories

## Quick Example

```nix
# flake.nix
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
        registry.src = ./registry;
      };
    };
}
```

Your directory structure becomes your configuration:

```
outputs/
  perSystem/
    packages.nix    → perSystem.packages
    devShells.nix   → perSystem.devShells
  nixosConfigurations/
    server.nix      → flake.nixosConfigurations.server

registry/
  hosts/
    server/         → registry.hosts.server
  modules/
    nixos/
      base.nix      → registry.modules.nixos.base
```

## Attribution

- Import features originally written by @vic in [import-tree](https://github.com/vic/import-tree)
- `.collectInputs` inspired by @vic's [flake-file](https://github.com/vic/flake-file)
- `.registry` inspired by @vic's [flake-aspects](https://github.com/vic/flake-aspects)
- `.tree` inspired by [flakelight](https://github.com/nix-community/flakelight)'s autoloading feature

## License

Apache-2.0 - see [LICENSE](https://github.com/Alb-O/imp/blob/main/LICENSE)
