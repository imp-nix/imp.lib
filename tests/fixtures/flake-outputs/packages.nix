# Test: file that wants pkgs -> should be wrapped per-system
{ pkgs, ... }:
{
  hello = pkgs.hello;
  testValue = "from-packages";
}
