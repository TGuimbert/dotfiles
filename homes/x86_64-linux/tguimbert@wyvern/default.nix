{ inputs, ... }:
{
  imports = [
    inputs.scortex.nixosModules.home-manager.scortex
  ];

  scortex = {
    impermanence = {
      enable = true;
      username = "tguimbert";
    };
    devOpsTools.enable = true;
  };
}
