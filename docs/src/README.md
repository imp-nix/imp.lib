# Imp 😈

<!-- Source: docs/src/README.md (repo root README.md symlinks from here) -->

Nix flakes require explicit imports. Add a module, update the imports list. Reorganize your directory structure, fix every relative path. Imp removes this busywork: point it at a directory and it imports everything inside, mapping filesystem paths to attribute names.

```nix
{ inputs, ... }:
{
  imports = [ (inputs.imp ./modules) ];
}
```

Add a file to `modules/`, it gets imported. Remove it, gone. No filepath bookkeeping.

## Beyond imports

Directory-based imports are the foundation. Imp builds five more things on top:

**Registries** give modules names instead of paths. Instead of `../../../modules/nixos/base.nix`, write `registry.modules.nixos.base`. Rename a directory and the migration tool scans for broken references, matches them to new paths by leaf name, and generates ast-grep commands to rewrite them.

**Config trees** map directory structure to NixOS option paths. The file `programs/git.nix` sets `programs.git`. Your directory layout becomes a visual index of what's configured.

**Input collection** scatters flake inputs next to the code that uses them. A formatter module declares its `treefmt-nix` dependency inline with `__inputs`; imp collects these and regenerates `flake.nix`.

**Export sinks** reverse the import direction. Features declare where their configuration should land (`__exports."nixos.role.desktop"`), and consumers import the merged result. Multiple features targeting the same sink merge according to their strategy. This decouples features from the hosts that use them.

**Host declarations** generate `nixosConfigurations` from `__host` attributes in the registry. Declare system, stateVersion, which sinks to import, and optional Home Manager integration. Imp assembles the configuration, no separate output file required.

## Installation

```nix
{
  imp.treeWith lib (f: f { inherit pkgs; }) ./outputs
  # { packages.hello = <derivation>; apps.run = <derivation>; }
}
```

## Export sinks

Features export configuration fragments to named sinks:

```nix
# registry/features/audio.nix
{
  __exports."desktop.nixos" = {
    value = { services.pipewire.enable = true; };
  };
}
```

The flake-parts module collects these and exposes them as `flake.exports`. Consumers import the merged sink:

```nix
{ exports, ... }:
{
  imports = [ exports.desktop.nixos.__module ];
}
```

Multiple features targeting the same sink merge according to their strategy (deep merge by default).

## Host declarations

Define hosts in the registry with `__host`:

```nix
# registry/hosts/workstation/default.nix
{
  __host = {
    system = "x86_64-linux";
    stateVersion = "24.11";
    sinks = [ "desktop.nixos" ];
    hmSinks = [ "desktop.hm" ];
    user = "alice";
  };
  config = ./config;
}
```

Enable host generation in your flake config:

```nix
imp = {
  registry.src = ./registry;
  hosts.enable = true;
};
```

Imp scans for `__host` declarations and generates `flake.nixosConfigurations.workstation`. The `sinks` field imports export sinks; `user` wires up Home Manager integration. No separate nixosConfiguration file needed.

## Optional features

Documentation generation and dependency visualization are opt-in modules with their own inputs.

**Documentation** with [imp.docgen](https://github.com/imp-nix/imp.docgen).

Run `nix run .#visualize` to analyze your registry and create a force graph visualization in the browser.

## Documentation

[Full docs](https://imp-nix.github.io/imp.lib)
