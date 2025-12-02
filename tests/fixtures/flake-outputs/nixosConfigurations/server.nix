# Test: file that uses other args from the base args
{ inputs, ... }:
{
  type = "nixos";
  hasInputs = inputs ? self;
}
