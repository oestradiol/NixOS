{ inputs, ... }:
{
  imports = [ inputs.hardening.nixosModules.home-shell ];
  home.stateVersion = "26.05";
}
