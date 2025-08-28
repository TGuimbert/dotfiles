{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.tguimbert.virtualisation;
  username = config.tguimbert.user.name;
in
{
  config = mkIf (cfg.containerPlatform == "docker") {
    virtualisation.docker = {
      enable = true;
      storageDriver = "overlay2";
      autoPrune.enable = true;
    };
    users.users.${username}.extraGroups = [ "docker" ];

    environment.systemPackages = with pkgs; [
      docker-compose
      minikube
    ];

    environment.persistence."/persistent" = {
      hideMounts = true;
      directories = [
        "/var/lib/docker"
      ];
    };

    snowfallorg.users.${username}.home.config = {
      home.file = {
        minikubeConfig = mkDefault {
          target = ".minikube/config/config.json";
          text = builtins.toJSON {
            container-runtime = "docker";
            rootless = false;
          };
        };
      };
    };
  };
}
