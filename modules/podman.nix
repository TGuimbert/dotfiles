{ ... }:
{
  nixos.modules.podman =
    { pkgs, ... }:
    {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };

      environment.systemPackages = with pkgs; [
        podman-compose
        minikube
      ];

      home-manager.users.tguimbert = {
        home.file.minikubeConfig = {
          target = ".minikube/config/config.json";
          text = builtins.toJSON {
            container-runtime = "containerd";
            rootless = true;
          };
        };

        home.persistence."/persistent" = {
          directories = [ ".minikube" ];
          files = [ ".docker/config.json" ];
        };
      };
    };
}
