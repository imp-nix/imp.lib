# Test: file without pkgs/system -> should NOT be wrapped, called directly
{ lib, ... }:
{
  type = "nixos";
  value = lib.id "workstation-config";
}
