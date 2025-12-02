# Test: file that wants system but not pkgs -> should be wrapped per-system
{ system, ... }:
{
  currentSystem = system;
}
