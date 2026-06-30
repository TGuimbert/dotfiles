{ ... }:
{
  nixos.modules.docker =
    { pkgs, lib, ... }:
    {
      virtualisation.docker = {
        enable = true;
        storageDriver = "overlay2";
        autoPrune.enable = true;
      };
      users.users.tguimbert.extraGroups = [ "docker" ];

      environment.systemPackages = [ pkgs.docker-compose ];

      environment.persistence."/persistent" = {
        hideMounts = true;
        directories = [
          "/var/lib/docker"
        ];
      };

      home-manager.users.tguimbert = {
        home.file = {
          minikubeConfig = lib.mkDefault {
            target = ".minikube/config/config.json";
            text = builtins.toJSON {
              container-runtime = "docker";
              rootless = false;
            };
          };
        };

        home.persistence."/persistent".files = [ ".docker/config.json" ];
      };
    };
}
