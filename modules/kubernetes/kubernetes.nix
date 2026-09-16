{ config, ... }: {
  homeManager.modules = {
    gui.imports = [ config.homeManager.modules.kubernetes ];

    kubernetes =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        home.packages = with pkgs; [
          kubectl
          kubelogin
          fluxcd
          kind
          kubectx
          (lib.lowPrio minikube)
        ];

        programs.k9s.enable = true;

        programs.nushell.shellAliases.k = lib.mkIf config.programs.nushell.enable "kubectl";
        programs.zsh = lib.mkIf config.programs.zsh.enable {
          shellAliases.k = "kubectl";
          initContent = lib.mkOrder 1100 ''
            source <(${lib.getExe pkgs.kubectl} completion zsh)
            compdef __start_kubectl k
          '';
        };

        xdg.configFile = {
          "k9s/plugins.yaml".source = ./plugins.yaml;
          "k9s/views.yaml".source = ./views.yaml;
        };
      };
  };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.directories = [
    ".kube"
    ".minikube"
  ];
}
