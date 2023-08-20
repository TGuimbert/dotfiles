{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.tg.gaming;
in
{
  options.tg.gaming = {
    enable = mkEnableOption "gaming stuff";
  };

  config = mkIf cfg.enable {
    programs.steam.enable = true;
    hardware.xpadneo.enable = true;
    environment.systemPackages = with pkgs; [
      protonup-ng
      heroic
      lutris
      clonehero
    ];
  };
}
