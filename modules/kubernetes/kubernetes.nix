{ ... }:
{
  homeManager.modules.gui =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        kubectl
        kubelogin
        fluxcd
        kind
        kubectx
        minikube
      ];

      programs.k9s.enable = true;

      xdg.configFile = {
        "k9s/plugins.yaml".source = ./plugins.yaml;
        "k9s/views.yaml".source = ./views.yaml;
      };

      home.persistence."/persistent".directories = [
        ".kube"
        ".minikube"
      ];
    };
}
