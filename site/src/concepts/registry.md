# The Registry

The registry provides named access to modules, replacing relative path imports with semantic names.

## Why Use a Registry?

Without registry:
```nix
imports = [
  ../../../hosts/server/default.nix
  ../../modules/nixos/base.nix
  ../../modules/nixos/features/networking.nix
];
```

With registry:
```nix
modules = imp.imports [
  registry.hosts.server
  registry.modules.nixos.base
  registry.modules.nixos.features.networking
];
```

Benefits:
- **Refactor-friendly** - Move files without updating every import
- **Self-documenting** - Names describe what modules do
- **Autocomplete** - IDEs can complete registry paths
- **Migration tooling** - Detect and fix broken references

## Setting Up

Configure the registry in your flake-parts config:

```nix
# nix/flake/default.nix
inputs:
flake-parts.lib.mkFlake { inherit inputs; } {
  imports = [ inputs.imp.flakeModules.default ];

  imp = {
    src = ../outputs;
    registry.src = ../registry;  # Root of your registry
  };
}
```

## Directory Structure

```
registry/
  hosts/
    server/
      default.nix       # -> registry.hosts.server
    workstation/
      default.nix       # -> registry.hosts.workstation
  modules/
    nixos/              # No default.nix
      base.nix          # -> registry.modules.nixos.base
      features/
        networking.nix  # -> registry.modules.nixos.features.networking
    home/
      base.nix          # -> registry.modules.home.base
  users/
    alice/
      default.nix       # -> registry.users.alice
```

## Using the Registry

The `registry` argument is automatically passed to all files:

```nix
# outputs/nixosConfigurations/server.nix
{ lib, inputs, imp, registry, ... }:
lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs imp registry; };
  modules = imp.imports [
    registry.hosts.server
    registry.modules.nixos.base
    registry.modules.nixos.features.networking
  ];
}
```

### imp.imports

Use `imp.imports` to handle mixed content:

```nix
modules = imp.imports [
  registry.hosts.server                    # Path -> imported
  registry.modules.nixos.base              # Path -> imported
  inputs.disko.nixosModules.default        # Module -> passed through
  { services.openssh.enable = true; }      # Inline config -> passed through
];
```

### Importing Directories

Directories without `default.nix` have a `__path` attribute:

```nix
# Import all modules in a directory
imports = [ (imp registry.modules.nixos.features.__path) ];

# Or use the directory attrset directly with imp
imports = [ (imp registry.modules.nixos.features) ];
```

## Registry Values

Each registry entry is a path to the file or directory:

```nix
registry.hosts.server          # = /path/to/registry/hosts/server (directory)
registry.modules.nixos.base    # = /path/to/registry/modules/nixos/base.nix
```

For directories without `default.nix`:

```nix
registry.modules.nixos         # Attrset with children + __path
registry.modules.nixos.__path  # = /path/to/registry/modules/nixos
registry.modules.nixos.base    # = /path/to/registry/modules/nixos/base.nix
```

## Explicit Overrides

Add or override registry entries:

```nix
imp.registry.modules = {
  # Add modules from other sources
  "nixos.disko" = inputs.disko.nixosModules.default;
};
```

## See Also

- [Registry Migration](../guides/registry-migration.md) - Fix broken references after renames
- [Registry Visualization](../guides/registry-visualization.md) - View dependency graph
- [Naming Conventions](./naming-conventions.md) - How files map to names
