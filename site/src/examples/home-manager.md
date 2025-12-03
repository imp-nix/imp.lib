# Home Manager

A Home Manager configuration using Imp with config trees and composable features.

## Directory Structure

```
registry/
  users/
    alice/
      default.nix
      programs/
        git.nix
        zsh.nix
        neovim.nix
      services/
        gpg-agent.nix
  modules/
    home/
      features/
        shell/
          default.nix
          programs/
            zsh.nix
            starship.nix
        devTools/
          programs/
            git.nix
            neovim.nix
```

## User Configuration

### registry/users/alice/default.nix

```nix
{ imp, registry, ... }:
{
  imports = [
    # Base features
    registry.modules.home.features.shell
    registry.modules.home.features.devTools
    
    # User-specific config tree
    (imp.configTree ./.)
  ];
  
  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "24.05";
}
```

### registry/users/alice/programs/git.nix

```nix
# Simple attrset - no function needed for static config
{
  enable = true;
  userName = "Alice Smith";
  userEmail = "alice@example.com";
  
  extraConfig = {
    init.defaultBranch = "main";
    pull.rebase = true;
  };
  
  delta.enable = true;
}
```

### registry/users/alice/programs/zsh.nix

```nix
{ lib, ... }:
{
  # Override/extend base shell config
  shellAliases = {
    # User-specific aliases
    projects = "cd ~/projects";
  };
  
  initContent = lib.mkAfter ''
    # Personal init
    export EDITOR="nvim"
  '';
}
```

## Composable Features

### registry/modules/home/features/shell/default.nix

```nix
{ imp, ... }:
{
  imports = [ (imp.configTree ./.) ];
}
```

### registry/modules/home/features/shell/programs/zsh.nix

```nix
{
  enable = true;
  enableCompletion = true;
  autosuggestion.enable = true;
  syntaxHighlighting.enable = true;
  
  history = {
    size = 10000;
    save = 10000;
    ignoreDups = true;
  };
  
  shellAliases = {
    ll = "ls -la";
    ".." = "cd ..";
  };
}
```

### registry/modules/home/features/shell/programs/starship.nix

```nix
{
  enable = true;
  settings = {
    add_newline = false;
    character = {
      success_symbol = "[➜](bold green)";
      error_symbol = "[➜](bold red)";
    };
  };
}
```

## Merging Features

For more complex composition, use `mergeConfigTrees`:

### registry/users/alice/default.nix (alternative)

```nix
{ imp, registry, ... }:
{
  imports = [
    (imp.mergeConfigTrees { strategy = "merge"; } [
      registry.modules.home.features.shell
      registry.modules.home.features.devTools
      ./.  # User-specific overrides
    ])
  ];
  
  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "24.05";
}
```

With `"merge"` strategy:
- Lists are concatenated
- `shellAliases` from all sources are combined
- Use `lib.mkBefore`/`lib.mkAfter` to control order

## Flake Integration

### outputs/homeConfigurations/alice@workstation.nix

```nix
{ inputs, nixpkgs, imp, registry, ... }:
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  extraSpecialArgs = { inherit inputs imp registry; };
  modules = [ (import registry.users.alice) ];
}
```

## Building

```sh
# Build the home configuration
home-manager build --flake .#alice@workstation

# Switch to the configuration  
home-manager switch --flake .#alice@workstation
```

## Tips

1. **Use config trees for programs** - Each program gets its own file
2. **Create feature modules** - Reusable across users
3. **Override in user config** - User-specific customization
4. **Use merge strategy** - When you want additive composition

## See Also

- [Config Trees](../guides/config-trees.md) - Detailed config tree guide
- [Merging Config Trees](../guides/merging-config-trees.md) - Composition strategies
- [NixOS Configuration](./nixos-configuration.md) - NixOS example
