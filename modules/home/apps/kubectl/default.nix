{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.tguimbert.apps.kubectl;
in
{
  options.tguimbert.apps.kubectl = {
    enable = mkEnableOption "Whether to enable support for Kubectl.";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      kubectl
    ];
    home.persistence."/persistent/home/tguimbert" = {
      directories = [
        ".kube"
      ];
    };
  };
}
