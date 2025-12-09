/**
  Build nixosConfigurations from collected host declarations.

  Takes host declarations collected by collect-hosts.nix and generates
  nixosConfigurations attrset suitable for flake outputs.

  # Arguments

  lib
  : nixpkgs lib (must have nixosSystem)

  imp
  : Bound imp instance with lib

  hosts
  : Output from collectHosts

  flakeArgs
  : Standard flake args { self, inputs, registry, exports, ... }

  hostDefaults
  : Default values for host config (optional)
*/
{
  lib,
  imp,
  hosts,
  flakeArgs,
  hostDefaults ? { },
}:
let
  inherit (flakeArgs)
    self
    inputs
    registry
    exports
    ;

  # Resolve a registry path string to a value
  # "hosts.shared.base" -> registry.hosts.shared.base
  resolveRegistryPath =
    pathStr:
    let
      parts = lib.splitString "." pathStr;
    in
    lib.getAttrFromPath parts registry;

  # Resolve an input path string to a value
  # "nixos-wsl.nixosModules.default" -> inputs.nixos-wsl.nixosModules.default
  resolveInputPath =
    pathStr:
    let
      parts = lib.splitString "." pathStr;
    in
    lib.getAttrFromPath parts inputs;

  # Build modules for a single host
  buildHostModules =
    hostName: hostDef:
    let
      host = hostDef.__host;
      configPath = hostDef.config;
      extraConfig = hostDef.extraConfig;

      # Resolve base config trees
      basePaths = map (base: if builtins.isString base then (resolveRegistryPath base).__path else base) (
        host.bases or [ ]
      );

      # Build merged config tree from bases + host config
      configTreeModule =
        if basePaths != [ ] || configPath != null then
          imp.mergeConfigTrees (basePaths ++ lib.optional (configPath != null) configPath)
        else
          { };

      # Resolve sink exports
      resolveSink =
        sinkPath:
        let
          parts = lib.splitString "." sinkPath;
        in
        (lib.getAttrFromPath parts exports).__module;

      sinkModules = map resolveSink (host.sinks or [ ]);

      # HM integration module (if user specified)
      hmModule =
        if host.user or null != null then
          let
            hmSinkModules = map resolveSink (host.hmSinks or [ ]);
            userName = host.user;
            userRegistry =
              if registry ? users && registry.users ? ${userName} then [ registry.users.${userName} ] else [ ];
          in
          {
            home-manager = {
              extraSpecialArgs = {
                inherit
                  inputs
                  exports
                  imp
                  registry
                  ;
              };
              useGlobalPkgs = true;
              useUserPackages = true;

              users.${userName} = {
                imports = hmSinkModules ++ imp.imports userRegistry;
              };
            };
          }
        else
          { };

      # Resolve extra modules - can be:
      # - Registry path strings: "mod.nixos.features.desktop.keyboard"
      # - Input path strings prefixed with @: "@nixos-wsl.nixosModules.default"
      # - Raw modules (functions or attrsets)
      resolveModule =
        mod:
        if builtins.isString mod then
          if lib.hasPrefix "@" mod then
            resolveInputPath (lib.removePrefix "@" mod)
          else
            resolveRegistryPath mod
        else
          mod;

      extraModules = map resolveModule (host.modules or [ ]);

      # All modules combined
      allModules = [
        configTreeModule
        inputs.home-manager.nixosModules.home-manager
      ]
      ++ sinkModules
      ++ [ hmModule ]
      ++ imp.imports extraModules
      ++ lib.optional (extraConfig != null) extraConfig
      ++ [
        { system.stateVersion = host.stateVersion; }
      ];
    in
    allModules;

  # Build a single nixosConfiguration
  buildHost =
    hostName: hostDef:
    let
      host = hostDef.__host;
      system = host.system or hostDefaults.system or "x86_64-linux";
    in
    lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit
          self
          inputs
          imp
          registry
          exports
          ;
      };
      modules = buildHostModules hostName hostDef;
    };

  # Build all hosts
  nixosConfigurations = lib.mapAttrs buildHost hosts;

in
nixosConfigurations
