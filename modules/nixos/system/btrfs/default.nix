{ config, lib, ... }:
with lib;
let
  cfg = config.tguimbert.system.btrfs;
in
{
  options.tguimbert.system.btrfs = {
    enable = mkEnableOption "Whether to enable BTRFS support.";
  };

  config = mkIf cfg.enable {
    services.btrfs.autoScrub.enable = true;
  };
}
