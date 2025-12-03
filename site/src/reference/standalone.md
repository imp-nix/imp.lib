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
