/**
  Generate `nixosConfigurations` from collected host declarations.

  Takes the output of `collectHosts` and produces an attrset of NixOS system
  configurations suitable for `flake.nixosConfigurations`. Each host's `__host`
  schema controls what modules are assembled and how Home Manager integrates.

  # Type

  ```
  buildHosts :: {
    lib,              # nixpkgs lib (needs nixosSystem)
    imp,              # bound imp instance (imp.withLib lib)
    hosts,            # output from collectHosts
    flakeArgs,        # { self, inputs, registry, exports, ... }
    hostDefaults?,    # default values for host fields
  } -> { <hostName> = <nixosConfiguration>; }
  ```

  # Module assembly

  For each host, modules are assembled in order:

  1. Merged config tree from `bases` paths plus `config` path (via `imp.mergeConfigTrees`)
  2. `home-manager.nixosModules.home-manager`
  3. Resolved sink modules from `sinks` list
  4. Home Manager integration module (if `user` is set)
  5. Resolved extra modules from `modules` list
  6. `extraConfig` module (if present)
  7. `{ system.stateVersion = ...; }`

  # Path resolution

  String values in `bases`, `sinks`, `hmSinks`, and `modules` resolve against
  either the registry or flake inputs:

  - `"hosts.shared.base"` resolves to `registry.hosts.shared.base`
  - `"@nixos-wsl.nixosModules.default"` resolves to `inputs.nixos-wsl.nixosModules.default`

  The `@` prefix distinguishes input paths from registry paths.

  # Home Manager integration

  When `user` is set, the generated configuration includes:

  ```nix
  {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = { inputs, exports, imp, registry };
      users.${user}.imports = [ <hmSink modules> <registry.users.${user} if exists> ];
    };
  }
  ```

  # Example

  ```nix
  buildHosts {
    inherit lib imp;
    hosts = collectHosts ./registry/hosts;
    flakeArgs = { inherit self inputs registry exports; };
    hostDefaults = { system = "x86_64-linux"; };
  }
  # => { desktop = <nixosConfiguration>; server = <nixosConfiguration>; }
  ```
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
