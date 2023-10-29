{ config, pkgs, lib, ... }:
with lib;
let cfg = config.tguimbert.system.secure-boot;
in
{
  options.tguimbert.system.secure-boot = {
    enable = mkEnableOption "Whether to enable Secure Boot with Lanzaboote.";
  };

  config = mkIf cfg.enable {
    boot = {
      loader.systemd-boot.enable = mkForce false;

      lanzaboote = {
        enable = true;
        pkiBundle = "/etc/secureboot";
      };
    };

    environment = {
      persistence = mkIf config.tguimbert.system.impermanence.enable {
        "/persist-root" = {
          directories = [
            "/etc/secureboot"
          ];
        };
      };

      systemPackages = with pkgs; [
        sbctl
      ];
    };
  };
}
