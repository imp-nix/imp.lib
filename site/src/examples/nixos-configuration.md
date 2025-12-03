# NixOS Configuration

A complete NixOS configuration using Imp with registry and flake-parts.

## Directory Structure

```
my-flake/
  flake.nix
  nix/
    flake/
      default.nix       # Flake entry point
      inputs.nix        # Core inputs
    outputs/
      nixosConfigurations/
        server.nix
        workstation.nix
      perSystem/
        packages.nix
    registry/
      hosts/
        server/
          default.nix
          hardware.nix
        workstation/
          default.nix
          hardware.nix
      modules/
        nixos/
          base.nix
          features/
            networking.nix
            ssh.nix
      users/
        alice/
          default.nix
```

## flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    imp.url = "github:Alb-O/imp";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: import ./nix/flake inputs;
}
```

## nix/flake/default.nix

```nix
inputs:
let
  inherit (inputs) flake-parts;
in
flake-parts.lib.mkFlake { inherit inputs; } {
  imports = [ inputs.imp.flakeModules.default ];

  systems = [ "x86_64-linux" "aarch64-linux" ];

  imp = {
    src = ../outputs;
    registry.src = ../registry;
  };
}
```

## nix/outputs/nixosConfigurations/server.nix

```nix
{ lib, inputs, imp, registry, ... }:
lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs imp registry; };
  modules = imp.imports [
    registry.hosts.server
    registry.modules.nixos.base
    registry.modules.nixos.features.ssh
  ];
}
```

## nix/registry/hosts/server/default.nix

```nix
{ inputs, imp, registry, ... }:
{
  imports = [
    ./hardware.nix
    (imp.configTree ./config)
  ];

  # Home Manager for users
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs imp registry; };
    users.alice = import registry.users.alice;
  };
}
```

## nix/registry/hosts/server/config/

```
config/
  networking.nix
  boot.nix
  services/
    nginx.nix
```

```nix
# config/networking.nix
{
  hostName = "server";
  firewall.allowedTCPPorts = [ 80 443 ];
}
```

```nix
# config/boot.nix
{
  loader.systemd-boot.enable = true;
  loader.efi.canTouchEfiVariables = true;
}
```

## nix/registry/modules/nixos/base.nix

```nix
{ lib, pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
  ];
  
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
}
```

## nix/registry/modules/nixos/features/ssh.nix

```nix
{ lib, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
```

## nix/registry/users/alice/default.nix

```nix
{ imp, ... }:
{
  imports = [ (imp.configTree ./.) ];
  
  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "24.05";
}
```

## Building

```sh
# Build the server configuration
nixos-rebuild build --flake .#server

# Switch to the configuration
sudo nixos-rebuild switch --flake .#server
```

## See Also

- [Home Manager](./home-manager.md) - Home Manager specific example
- [Full Flake Structure](./full-flake.md) - Complete flake with all features
- [The Registry](../concepts/registry.md) - Registry explanation
