{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.tguimbert.apps.signal;
in
{
  options.tguimbert.apps.signal = {
    enable = mkEnableOption "Whether to enable support for Signal.";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      signal-desktop
    ];
    home.persistence."/persistent/home/tguimbert" = {
      directories = [
        ".config/Signal"
      ];
    };
  };
}
