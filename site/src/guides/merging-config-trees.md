# Merging Config Trees

Merge multiple config trees to create composable, layered configurations.

## Use Case

You have feature sets that can be combined:

```
features/
  shell/
    programs/
      zsh.nix
      starship.nix
  devTools/
    programs/
      git.nix
      neovim.nix
  devShell/
    programs/
      zsh.nix       # Additional shell config for dev
```

You want `devShell` to include `shell` + `devTools` + its own additions.

## Basic Usage

```nix
# features/devShell/default.nix
{ imp, registry, ... }:
{
  imports = [
    (imp.mergeConfigTrees [
      registry.modules.home.features.shell     # Base shell config
      registry.modules.home.features.devTools  # Dev tools
      ./.                                       # Local additions
    ])
  ];
}
```

## Merge Strategies

### Override (Default)

Later values replace earlier ones using `recursiveUpdate`:

```nix
imp.mergeConfigTrees { strategy = "override"; } [
  ../base    # programs.zsh.initContent = "base"
  ./.        # programs.zsh.initContent = "override" <- wins
]
```

### Merge

Values are combined using the module system's `mkMerge`:

```nix
imp.mergeConfigTrees { strategy = "merge"; } [
  ../base    # programs.zsh.initContent = "base"
  ./.        # programs.zsh.initContent = "local"
]
# Result: initContent contains both (order depends on module priorities)
```

With `"merge"` strategy:
- Lists are concatenated
- Attrs are merged deeply
- Use `lib.mkBefore`/`lib.mkAfter` to control order

## Controlling Order

With merge strategy, use priority functions:

```nix
# features/devShell/programs/zsh.nix
{ lib, ... }:
{
  # Append after base's initContent
  initContent = lib.mkAfter ''
    export EDITOR="nvim"
  '';

  # Merge shell aliases with base
  shellAliases = {
    nb = "nix build";
    nd = "nix develop";
  };
}
```

## Extra Arguments

Pass additional arguments to all config files:

```nix
imp.mergeConfigTrees {
  strategy = "merge";
  extraArgs = {
    myVar = "value";
    helpers = import ./lib.nix;
  };
} [ ../base ./. ]
```

## Shorthand Syntax

Without options, just pass a list:

```nix
# Uses default "override" strategy
imp.mergeConfigTrees [ ../base ./. ]
```

## Real-World Example

```
registry/modules/home/
  features/
    shell/
      default.nix
      programs/
        zsh.nix          # enable=true, basic config
        starship.nix
    devTools/
      programs/
        git.nix
        neovim.nix
    devShell/
      default.nix        # Merges shell + devTools + local
      programs/
        zsh.nix          # Dev-specific aliases, EDITOR
```

```nix
# features/devShell/default.nix
{ imp, registry, ... }:
{
  imports = [
    (imp.mergeConfigTrees { strategy = "merge"; } [
      registry.modules.home.features.shell
      registry.modules.home.features.devTools
      ./.
    ])
  ];
}
```

```nix
# features/devShell/programs/zsh.nix
{ lib, ... }:
{
  shellAliases = {
    nb = "nix build";
    nd = "nix develop";
    nr = "nix run";
  };

  initContent = lib.mkAfter ''
    export EDITOR="nvim"
    export NIX_BUILD_CORES=8
  '';
}
```

## When to Use Each Strategy

**Use `"override"` when:**
- Creating variants that replace base config
- You want simpler mental model
- Order doesn't matter

**Use `"merge"` when:**
- Building additive layers
- Values should accumulate (lists, sets)
- You need fine-grained ordering control

## See Also

- [Config Trees](./config-trees.md) - Basic config tree usage
- [Directory Imports](../concepts/directory-imports.md) - How imports work
