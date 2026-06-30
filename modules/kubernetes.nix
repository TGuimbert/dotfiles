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
      ];

      home.persistence."/persistent".directories = [ ".kube" ];
    };
}
