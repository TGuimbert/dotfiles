{ pkgs, lib, inputs, ... }:
with lib;
{
  imports = [
    inputs.scortex.nixosModules.home-manager.scortex
  ];

  home = {
    packages = with pkgs; [
      zoom-us
      chromium
    ];

    persistence."/persist-home/tguimbert" = {
      directories = [
        ".zoom"
      ];
      files = [
        ".config/zoom.conf"
        ".config/zoomus.conf"
      ];
      allowOther = true;
    };
  };

  scortex = {
    impermanence = {
      enable = true;
      username = "tguimbert";
    };
    devOpsTools.enable = true;
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";
}
