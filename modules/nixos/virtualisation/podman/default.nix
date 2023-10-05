{ config, lib, ... }:
with lib;
let cfg = config.tguimbert.virtualisation;
in
{
  config = mkIf (cfg.containerPlatform == "podman") {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
