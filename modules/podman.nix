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

      environment.systemPackages = [ pkgs.podman-compose ];

      preservation.preserveAt."/persistent".users.tguimbert = {
        files = [ ".docker/config.json" ];
        directories = [ ".local/share/containers" ];
      };

      home-manager.users.tguimbert = {
        home.file.minikubeConfig = {
          target = ".minikube/config/config.json";
          text = builtins.toJSON {
            container-runtime = "containerd";
            rootless = true;
          };
        };
      };
    };
}
