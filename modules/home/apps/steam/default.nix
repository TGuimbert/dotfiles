{ lib, config, ... }:
with lib;
let
  cfg = config.tg.gaming;
in
{
  options.tg.gaming = {
    enable = mkEnableOption "gaming stuff";
  };

  config = mkIf cfg.enable {
    home.persistence."/persist-home/tguimbert" = {
      directories = [
        {
          directory = ".local/share/Steam";
          method = "symlink";
        }
        {
          directory = ".steam";
          method = "symlink";
        }
        ".clonehero"
        ".config/unity3d/srylain Inc_/Clone Hero"
      ];
      allowOther = true;
    };
  };
}
