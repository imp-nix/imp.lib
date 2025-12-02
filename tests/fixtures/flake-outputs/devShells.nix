# Test: file with both pkgs and other args
{ pkgs, inputs, ... }:
{
  combined = pkgs.hello;
  hasInputs = inputs ? self;
}
