# Directory-Based Imports

Imp's core feature is treating directories as module collections. Instead of manually listing imports, point Imp at a directory and it discovers all `.nix` files automatically.

## How It Works

Given this directory:

```
modules/
  networking.nix
  users/
    alice.nix
    bob.nix
  services/
    nginx.nix
    postgres.nix
```

Using Imp:

```nix
{ inputs, ... }:
{
  imports = [ (inputs.imp ./modules) ];
}
```

Is equivalent to:

```nix
{
  imports = [
    ./modules/networking.nix
    ./modules/users/alice.nix
    ./modules/users/bob.nix
    ./modules/services/nginx.nix
    ./modules/services/postgres.nix
  ];
}
```

## Filtering Imports

You can filter which files get imported:

```nix
let
  imp = inputs.imp.withLib lib;
in
{
  imports = [
    # Only files containing "/services/" in their path
    (imp.filter (lib.hasInfix "/services/") ./modules)
    
    # Exclude test files
    (imp.filterNot (lib.hasSuffix ".test.nix") ./modules)
    
    # Match a regex pattern
    (imp.match ".*/(users|groups)/.*" ./modules)
  ];
}
```

## Conditional Loading

Load different modules based on conditions:

```nix
let
  imp = inputs.imp.withLib lib;
in
{
  imports = [
    (if isServer
      then imp.filter (lib.hasInfix "/server/") ./modules
      else imp.filter (lib.hasInfix "/desktop/") ./modules)
  ];
}
```

## Getting the File List

To see which files Imp will import:

```nix
let
  imp = inputs.imp.withLib lib;
in
imp.leafs ./modules
# => [ "/path/to/modules/networking.nix" "/path/to/modules/users/alice.nix" ... ]
```

## Deep Nesting

Imp recursively descends into all subdirectories. There's no depth limit:

```
config/
  level1/
    level2/
      level3/
        deep-module.nix  # Still found and imported
```

## See Also

- [Naming Conventions](./naming-conventions.md) - How files map to attributes
- [Config Trees](../guides/config-trees.md) - Map directory structure to option paths
