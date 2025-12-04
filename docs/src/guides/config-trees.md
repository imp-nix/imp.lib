# Config Trees

Map directory structure to option paths:

```
home/
  programs/
    git.nix      # -> programs.git = { ... }
    zsh.nix      # -> programs.zsh = { ... }
  services/
    gpg-agent.nix # -> services.gpg-agent = { ... }
```

Each file returns just that option's value:

```nix
# home/programs/git.nix
{
  enable = true;
  userName = "Alice";
}
```

## Usage

```nix
{ inputs, lib, ... }:
{
  imports = [ ((inputs.imp.withLib lib).configTree ./home) ];
}
```

With registry:

```nix
{ imp, ... }:
{
  imports = [ (imp.configTree ./.) ];
}
```

## Files can be functions

```nix
# programs/git.nix
{ pkgs, ... }:
{
  enable = true;
  package = pkgs.gitFull;
}
```

## Extra arguments

```nix
imp.configTreeWith { myVar = "value"; } ./config
```

## Building attribute trees

For non-module uses (e.g. packages or apps), use `.tree` or `.treeWith`:

```nix
# A tree of packages
let
  packages = (imp.withLib lib).tree ./packages;
in
packages.hello  # -> imported from ./packages/hello.nix
```

### Using treeWith for transformation

When each file exports a function that needs arguments:

```nix
# packages/hello.nix
{ pkgs }:
pkgs.hello

# Build with treeWith
imp.treeWith lib (f: f { inherit pkgs; }) ./packages
# => { hello = <derivation>; }
```

### Common treeWith patterns

Calling functions with arguments:

```nix
# Each file gets: { pkgs, lib }: { ... }
imp.treeWith lib (f: f { inherit pkgs lib; }) ./outputs
```

Adding metadata to all derivations:

```nix
imp.treeWith lib (drv: drv // { meta.priority = 5; }) ./packages
```

Wrap each module with common options:

```nix
imp.treeWith lib (mod: { imports = [ mod commonModule ]; }) ./modules
```

### Chaining with mapTree

For multiple transformations, chain `.mapTree`:

```nix
(imp.withLib lib)
  .mapTree (f: f { inherit pkgs; })  # Call with args
  .mapTree (drv: drv.overrideAttrs (old: { meta.license = lib.licenses.mit; }))
  .tree ./packages
```
