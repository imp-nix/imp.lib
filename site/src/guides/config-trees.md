# Config Trees

Config trees map directory structure directly to NixOS/Home Manager option paths, making configuration more organized and discoverable.

## The Problem

Traditional configuration puts everything in one file or requires manual organization:

```nix
# home.nix - everything in one place
{
  programs.git = { enable = true; userName = "Alice"; };
  programs.zsh = { enable = true; /* ... */ };
  programs.starship = { enable = true; /* ... */ };
  services.gpg-agent = { enable = true; /* ... */ };
  # ... hundreds more lines
}
```

## The Solution

With config trees, directory structure becomes option paths:

```
home/
  programs/
    git.nix      # -> programs.git = { ... }
    zsh.nix      # -> programs.zsh = { ... }
    starship.nix # -> programs.starship = { ... }
  services/
    gpg-agent.nix # -> services.gpg-agent = { ... }
```

Each file contains just that option's config:

```nix
# home/programs/git.nix
{
  enable = true;
  userName = "Alice";
  extraConfig = {
    init.defaultBranch = "main";
  };
}
```

## Usage

### Basic Usage

```nix
{ inputs, lib, ... }:
{
  imports = [ ((inputs.imp.withLib lib).configTree ./home) ];
}
```

### With Registry

```nix
# registry/users/alice/default.nix
{ imp, ... }:
{
  imports = [ (imp.configTree ./.) ];
}
```

Your user directory:

```
registry/users/alice/
  default.nix
  programs/
    git.nix
    zsh.nix
  services/
    gpg-agent.nix
```

## File Format

Config tree files are simpler than modules - they just return the option value:

```nix
# Without config tree (traditional module)
{ config, lib, pkgs, ... }:
{
  programs.git = {
    enable = true;
    userName = "Alice";
  };
}

# With config tree (programs/git.nix)
{
  enable = true;
  userName = "Alice";
}
```

### With Arguments

Files can be functions receiving module arguments:

```nix
# programs/git.nix
{ pkgs, ... }:
{
  enable = true;
  package = pkgs.gitFull;
  userName = "Alice";
}
```

### With lib

```nix
# programs/zsh.nix
{ lib, ... }:
{
  enable = true;
  initContent = lib.mkBefore ''
    # Early init
  '';
}
```

## Directory Modules

Directories with `default.nix` work as expected:

```
services/
  nginx/
    default.nix       # -> services.nginx = { ... }
```

```nix
# services/nginx/default.nix
{ lib, ... }:
{
  enable = true;
  virtualHosts."example.com" = { /* ... */ };
}
```

## Top-Level Options

For options at the root level, use files in the config tree root:

```
home/
  home-manager.nix   # -> home-manager = { ... }
  programs/
    git.nix
```

## Combining with Regular Imports

Mix config trees with regular module imports:

```nix
{ inputs, lib, imp, ... }:
{
  imports = [
    (imp.configTree ./config)        # Config tree
    ./modules/custom-module.nix       # Regular module
    inputs.foo.homeManagerModules.bar # External module
  ];
}
```

## Extra Arguments

Pass additional arguments to config files:

```nix
imp.configTree {
  extraArgs = { myVar = "value"; };
} ./config
```

## When to Use

**Use config trees when:**
- You have many programs/services to configure
- You want one file per program
- Configuration is mostly declarative values
- You want directory structure to reflect option structure

**Use regular modules when:**
- You need complex logic or conditionals
- Options affect multiple unrelated paths
- You're writing reusable library modules

## See Also

- [Merging Config Trees](./merging-config-trees.md) - Compose multiple config trees
- [Directory Imports](../concepts/directory-imports.md) - How imports work
