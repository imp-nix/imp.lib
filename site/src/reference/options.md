# Module Options

<!-- Auto-generated from src/flakeModule.nix - do not edit -->

## `imp.args` {#imp-args}

`attribute set of unspecified value` (default: `...`)

Extra arguments passed to all imported files.

Flake files receive: { lib, self, inputs, config, imp, registry, ... }
perSystem files receive: { pkgs, lib, system, self, self', inputs, inputs', imp, registry, ... }

User-provided args take precedence over defaults.

## `imp.flakeFile.coreInputs` {#imp-flakeFile-coreInputs}

`attribute set of unspecified value` (default: `...`)

Core inputs always included in flake.nix (e.g., nixpkgs, flake-parts).

**Example:**

```nix
{
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  flake-parts.url = "github:hercules-ci/flake-parts";
}

```

## `imp.flakeFile.description` {#imp-flakeFile-description}

`string` (default: `...`)

Flake description field.

## `imp.flakeFile.enable` {#imp-flakeFile-enable}

`boolean` (default: `...`)

Whether to enable flake.nix generation from \_\_inputs declarations.

**Example:**

```nix
true
```

## `imp.flakeFile.header` {#imp-flakeFile-header}

`string` (default: `...`)

Header comment for generated flake.nix.

## `imp.flakeFile.outputsFile` {#imp-flakeFile-outputsFile}

`string` (default: `...`)

Path to outputs file (relative to flake.nix).

## `imp.flakeFile.path` {#imp-flakeFile-path}

`absolute path` (default: `...`)

Path to flake.nix file to generate/check.

## `imp.perSystemDir` {#imp-perSystemDir}

`string` (default: `...`)

Subdirectory name for per-system outputs.

Files in this directory receive standard flake-parts perSystem args:
{ pkgs, lib, system, self, self', inputs, inputs', ... }

## `imp.registry.migratePaths` {#imp-registry-migratePaths}

`list of absolute path` (default: `...`)

Directories to scan for registry references when detecting renames.
If empty, defaults to [ imp.src ] when registry.src is set.

**Example:**

```nix
[ ./nix/outputs ./nix/flake ]

```

## `imp.registry.modules` {#imp-registry-modules}

`attribute set of unspecified value` (default: `...`)

Explicit module name -> path mappings.
These override auto-discovered modules from registry.src.

**Example:**

```nix
{
  specialModule = ./path/to/special.nix;
}

```

## `imp.registry.name` {#imp-registry-name}

`string` (default: `...`)

Attribute name used to inject the registry into file arguments.

Change this if "registry" conflicts with other inputs or arguments.

**Example:**

```nix
"impRegistry"
# Then in files:
# { impRegistry, ... }:
# { imports = [ impRegistry.modules.home ]; }

```

## `imp.registry.src` {#imp-registry-src}

`null or absolute path` (default: `...`)

Root directory to scan for building the module registry.

The registry maps directory structure to named modules.
Files can then reference modules by name instead of path.

**Example:**

```nix
./nix
# Structure:
#   nix/
#     users/alice/     -> registry.users.alice
#     modules/nixos/   -> registry.modules.nixos
#
# Usage in files:
#   { registry, ... }:
#   { imports = [ registry.modules.home ]; }

```

## `imp.src` {#imp-src}

`null or absolute path` (default: `...`)

Directory containing flake outputs to import.

Structure maps to flake-parts semantics:
outputs/
perSystem/ -> perSystem.\* (per-system outputs)
packages.nix -> perSystem.packages
devShells.nix -> perSystem.devShells
nixosConfigurations/ -> flake.nixosConfigurations
overlays.nix -> flake.overlays
systems.nix -> systems (optional, overrides top-level)
