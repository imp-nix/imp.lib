# Module Options

Configuration options for the imp flake-parts module.

## imp.src

**Type:** `path | null`

**Default:** `null`

Directory containing flake outputs to auto-load.

```nix
imp.src = ./outputs;
```

## imp.args

**Type:** `attrset`

**Default:** `{}`

Extra arguments passed to all files.

```nix
imp.args = {
  inherit inputs;
  myLib = import ./lib.nix;
};
```

## imp.perSystemDir

**Type:** `string`

**Default:** `"perSystem"`

Name of the subdirectory containing per-system outputs.

```nix
imp.perSystemDir = "per-system";
```

## imp.registry.name

**Type:** `string`

**Default:** `"registry"`

Attribute name for registry in function arguments.

```nix
imp.registry.name = "reg";
# Then use: { reg, ... }: reg.modules.nixos.base
```

## imp.registry.src

**Type:** `path | null`

**Default:** `null`

Root directory for module registry. Enables automatic registry injection into all files.

```nix
imp.registry.src = ./registry;
```

## imp.registry.modules

**Type:** `attrset`

**Default:** `{}`

Explicit name-to-path overrides for registry entries.

```nix
imp.registry.modules = {
  # Add external modules
  "nixos.disko" = inputs.disko.nixosModules.default;
  
  # Override auto-discovered path
  "hosts.server" = ./custom/server.nix;
};
```

## imp.registry.migratePaths

**Type:** `list of path`

**Default:** `[]`

Directories to scan for registry reference renames.

```nix
imp.registry.migratePaths = [
  ./outputs
  ./registry
];
```

## imp.flakeFile.enable

**Type:** `bool`

**Default:** `false`

Enable flake.nix generation with collected inputs.

```nix
imp.flakeFile.enable = true;
```

## imp.flakeFile.coreInputs

**Type:** `attrset`

**Default:** `{}`

Core inputs always included in generated flake.nix.

```nix
imp.flakeFile.coreInputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  flake-parts.url = "github:hercules-ci/flake-parts";
};
```

Or import from file:

```nix
imp.flakeFile.coreInputs = import ./inputs.nix;
```

## imp.flakeFile.outputsFile

**Type:** `string`

**Default:** `"./outputs.nix"`

Path to outputs file, relative to flake.nix.

```nix
imp.flakeFile.outputsFile = "./nix/flake";
```

Generated flake.nix will contain:

```nix
outputs = inputs: import ./nix/flake inputs;
```

## Example Configuration

```nix
flake-parts.lib.mkFlake { inherit inputs; } {
  imports = [ inputs.imp.flakeModules.default ];

  systems = [ "x86_64-linux" "aarch64-linux" ];

  imp = {
    src = ./outputs;
    args = { inherit inputs; };
    perSystemDir = "perSystem";
    
    registry = {
      src = ./registry;
      modules = {
        "nixos.disko" = inputs.disko.nixosModules.default;
      };
      migratePaths = [ ./outputs ];
    };
    
    flakeFile = {
      enable = true;
      coreInputs = import ./inputs.nix;
      outputsFile = "./nix/flake";
    };
  };
}
```

## See Also

- [Using with flake-parts](../guides/flake-parts.md) - Integration guide
- [API Methods](./methods.md) - Available methods
- [File Reference](./files.md) - Source files
