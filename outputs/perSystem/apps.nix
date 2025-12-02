{
  pkgs,
  system,
  nix-unit,
  ...
}:
{
  tests = {
    type = "app";
    program = toString (
      pkgs.writeShellScript "run-tests" ''
        ${nix-unit.packages.${system}.default}/bin/nix-unit --flake .#tests
      ''
    );
  };
}
