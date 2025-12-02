# Builds a NixOS/Home Manager module from directory structure
#
# Each file is a function receiving module args ({ config, lib, pkgs, ... })
# and returning an attrset. The file's path becomes the option path:
#
#   programs/git.nix     -> { programs.git = <result of calling file>; }
#   services/nginx.nix   -> { services.nginx = <result>; }
#   services/ssh/default.nix -> { services.ssh = <result>; }
#
# Usage:
#   imports = [ (imp.configTree ./home) ];
#
# Or with extra args:
#   imports = [ (imp.configTreeWith { inherit inputs; } ./home) ];
#
{
  lib,
  filterf,
  extraArgs ? { },
}:
let
  buildConfigTree =
    root:
    {
      config,
      lib,
      pkgs,
      ...
    }@moduleArgs:
    let
      args = moduleArgs // extraArgs;

      buildFromDir =
        dir:
        let
          entries = builtins.readDir dir;

          toAttrName =
            name:
            let
              withoutNix = lib.removeSuffix ".nix" name;
            in
            lib.removeSuffix "_" withoutNix;

          shouldInclude = name: !(lib.hasPrefix "_" name) && filterf (toString dir + "/" + name);

          processEntry =
            name: type:
            let
              path = dir + "/${name}";
              attrName = toAttrName name;
            in
            if type == "regular" && lib.hasSuffix ".nix" name then
              let
                fileContent = import path;
                value = if builtins.isFunction fileContent then fileContent args else fileContent;
              in
              {
                ${attrName} = value;
              }
            else if type == "directory" then
              let
                defaultPath = path + "/default.nix";
                hasDefault = builtins.pathExists defaultPath;
              in
              if hasDefault then
                let
                  fileContent = import path;
                  value = if builtins.isFunction fileContent then fileContent args else fileContent;
                in
                {
                  ${attrName} = value;
                }
              else
                { ${attrName} = buildFromDir path; }
            else
              { };

          filteredEntries = lib.filterAttrs (name: _: shouldInclude name) entries;
          processed = lib.mapAttrsToList processEntry filteredEntries;
        in
        lib.foldl' lib.recursiveUpdate { } processed;
    in
    {
      config = buildFromDir root;
    };
in
buildConfigTree
