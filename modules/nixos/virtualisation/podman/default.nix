{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.tguimbert.virtualisation;
  username = config.tguimbert.user.name;
in
{
  config = mkIf (cfg.containerPlatform == "podman") {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    environment.systemPackages = with pkgs; [
      podman-compose
      minikube
    ];

    snowfallorg.users.${username}.home.config = {
      home.file = {
        minikubeConfig = mkDefault {
          target = ".minikube/config/config.json";
          text = builtins.toJSON {
            container-runtime = "containerd";
            rootless = true;
          };
        };
      };
    };
  };
}
