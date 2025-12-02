{
  pkgs,
  nix-unit,
  ...
}:
{
  tests = {
    type = "app";
    program = toString (
      pkgs.writeShellScript "run-tests" ''
        ${nix-unit.packages.${pkgs.system}.default}/bin/nix-unit --flake .#tests
      ''
    );
  };
}
