{ config, pkgs, lib, ... }:
with lib;
{
  home.packages = with pkgs; [
    zoom-us
    slack
    chromium
    souatinoua
  ];

  home.persistence."/persist-home/tguimbert" = {
    directories = [
      ".config/Slack"
      ".zoom"
    ];
    files = [
      ".config/zoom.conf"
      ".config/zoomus.conf"
    ];
    allowOther = true;
  };

  scortex = {
    impermanence.enable = true;
    devOpsTools.enable = true;
  };

  home.file = {
    minikubeConfig = mkForce {
      target = ".minikube/config/config.json";
      text = builtins.toJSON {
        container-runtime = "docker";
        rootless = false;
      };
    };
  };
}
