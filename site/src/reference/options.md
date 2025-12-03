# Module Options

## imp.src

`path | null` (default: `null`)

Directory containing flake outputs to auto-load.

## imp.args

`attrset` (default: `{}`)

Extra arguments passed to all files.

## imp.perSystemDir

`string` (default: `"perSystem"`)

Subdirectory name for per-system outputs.

## imp.registry.name

`string` (default: `"registry"`)

Attribute name for registry in function arguments.

## imp.registry.src

`path | null` (default: `null`)

Root directory for module registry.

## imp.registry.modules

`attrset` (default: `{}`)

Explicit name-to-path overrides:

```nix
imp.registry.modules = {
  "nixos.disko" = inputs.disko.nixosModules.default;
};
```

## imp.registry.migratePaths

`list of path` (default: `[]`)

Directories to scan for registry reference renames.

## imp.flakeFile.enable

`bool` (default: `false`)

Enable flake.nix generation with collected inputs.

## imp.flakeFile.coreInputs

`attrset` (default: `{}`)

Core inputs always included in generated flake.nix.

## imp.flakeFile.outputsFile

`string` (default: `"./outputs.nix"`)

Path to outputs file, relative to flake.nix.

## Full example

```nix
imp = {
  src = ./outputs;
  args = { inherit inputs; };
  perSystemDir = "perSystem";
  registry = {
    src = ./registry;
    modules."nixos.disko" = inputs.disko.nixosModules.default;
    migratePaths = [ ./outputs ];
  };
  flakeFile = {
    enable = true;
    coreInputs = import ./inputs.nix;
    outputsFile = "./nix/flake";
  };
};
```
