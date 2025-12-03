# Basic Import

The simplest way to use Imp - import a directory as a NixOS/Home Manager module.

## Directory Structure

```
modules/
  networking.nix
  users/
    alice.nix
    bob.nix
  services/
    ssh.nix
    nginx.nix
```

## Usage

### In a NixOS Configuration

```nix
# configuration.nix
{ inputs, ... }:
{
  imports = [ (inputs.imp ./modules) ];
}
```

### In a flake

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    imp.url = "github:Alb-O/imp";
  };

  outputs = { nixpkgs, imp, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          (imp ./modules)
          ./hardware-configuration.nix
        ];
      };
    };
}
```

## Module Files

Each `.nix` file is a standard NixOS module:

```nix
# modules/networking.nix
{ config, lib, pkgs, ... }:
{
  networking.hostName = "myhost";
  networking.networkmanager.enable = true;
}
```

```nix
# modules/users/alice.nix
{ config, lib, pkgs, ... }:
{
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
}
```

```nix
# modules/services/ssh.nix
{ config, lib, pkgs, ... }:
{
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };
}
```

## Filtering

Import only specific modules:

```nix
{ inputs, lib, ... }:
let
  imp = inputs.imp.withLib lib;
in
{
  imports = [
    # Only service modules
    (imp.filter (lib.hasInfix "/services/") ./modules)
  ];
}
```

## Conditional Import

```nix
{ inputs, lib, config, ... }:
let
  imp = inputs.imp.withLib lib;
in
{
  imports = [
    (imp ./modules/base)
    
    # Server-specific modules
    (lib.optionalAttrs config.isServer 
      (imp ./modules/server))
  ];
}
```

## What Happens

When you write:

```nix
imports = [ (inputs.imp ./modules) ];
```

Imp:
1. Recursively finds all `.nix` files in `./modules`
2. Skips files starting with `_`
3. Returns a module that imports all found files

Equivalent to:

```nix
imports = [
  ./modules/networking.nix
  ./modules/users/alice.nix
  ./modules/users/bob.nix
  ./modules/services/ssh.nix
  ./modules/services/nginx.nix
];
```

## See Also

- [Directory Imports](../concepts/directory-imports.md) - Detailed explanation
- [Naming Conventions](../concepts/naming-conventions.md) - File naming rules
- [NixOS Configuration](./nixos-configuration.md) - More complex NixOS example
