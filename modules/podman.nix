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

      home-manager.users.tguimbert = {
        home.file.minikubeConfig = {
          target = ".minikube/config/config.json";
          text = builtins.toJSON {
            container-runtime = "containerd";
            rootless = true;
          };
        };

        home.persistence."/persistent".files = [ ".docker/config.json" ];
      };
    };
}
