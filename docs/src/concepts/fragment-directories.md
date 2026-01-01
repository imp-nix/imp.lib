# Fragment Directories

The `.d` pattern enables composable configuration where multiple sources contribute to a single output. This is particularly useful when external tools (like imp.gits) inject files into your project.

## Auto-merged directories

Directories ending in `.d` that match known flake output names are automatically merged:

```
outputs/
  perSystem/
    packages.d/
      00-core.nix       # { default = myPkg; foo = fooPkg; }
      10-extras.nix     # { bar = barPkg; }
    devShells.nix
```

Result:

```nix
self'.packages = { default = myPkg; foo = fooPkg; bar = barPkg; }
```

Files are processed in sorted order (00 before 10) and merged with `lib.recursiveUpdate`. Later files can override or extend earlier ones.

### Supported output names

Only these `.d` directories are auto-merged:

- `packages.d/`
- `devShells.d/`
- `checks.d/`
- `apps.d/`
- `overlays.d/`
- `nixosModules.d/`
- `homeModules.d/`
- `darwinModules.d/`
- `flakeModules.d/`
- `nixosConfigurations.d/`
- `darwinConfigurations.d/`
- `homeConfigurations.d/`
- `legacyPackages.d/`

## Manual fragment directories

Other `.d` directories are ignored by tree and consumed via `imp.fragments`:

```nix
{ pkgs, imp, ... }:
let
  shellHookFragments = imp.fragments ./shellHook.d;
in
{
  default = pkgs.mkShell {
    shellHook = shellHookFragments.asString;
  };
}
```

Common patterns:

| Directory      | Content               | Collection method             |
| -------------- | --------------------- | ----------------------------- |
| `shellHook.d/` | Shell scripts (`.sh`) | `imp.fragments` → `.asString` |
| `env.d/`       | Environment attrsets  | `imp.fragmentsWith` → `.asAttrs` |

## Merging base files with fragments

When both `foo.nix` and `foo.d/` exist for a mergeable output, they are combined:

```
outputs/
  packages.nix        # { default = myPkg; }
  packages.d/
    10-extras.nix     # { bar = barPkg; }
```

Result:

```nix
self'.packages = { default = myPkg; bar = barPkg; }
```

The base file (`foo.nix`) is imported first, then fragments from `foo.d/` are merged on top using `lib.recursiveUpdate`. This allows a base file to define core outputs while fragments extend them.

## Fragment file structure

Each fragment in a `.d` directory can use the standard patterns:

```nix
# Simple attrset
{ default = myPkg; }

# Function receiving args
{ pkgs, ... }:
{ default = pkgs.hello; }

# With __inputs for flake input collection
{
  __inputs.foo.url = "github:owner/foo";
  __functor = _: { pkgs, foo, ... }: { default = foo.packages.${pkgs.system}.bar; };
}
```

## Use case: injected dependencies

The `.d` pattern shines when external tools add files to your project. For example, with imp.gits syncing lintfra:

```
outputs/perSystem/
  packages.d/
    00-rust.nix         # Your rust packages
    10-lint.nix         # Injected by lintfra
  devShells.nix         # Your main devShell using inputsFrom
  devShells.d/
    10-lintfra.nix      # Injected lintfra devShell
```

Your `packages.d/00-rust.nix` defines the main packages. The injected `10-lint.nix` adds a lint command. Both are merged into `self'.packages` without any manual wiring.

For devShells, the injected `devShells.d/10-lintfra.nix` provides a composable shell that your `devShells.nix` can consume via `inputsFrom`:

```nix
# devShells.nix
{ pkgs, self', ... }:
{
  default = pkgs.mkShell {
    inputsFrom = [ self'.devShells.lintfra ];  # from devShells.d/
    packages = [ /* your packages */ ];
  };
}
```

This uses the standard Nix `inputsFrom` pattern for shell composition.
