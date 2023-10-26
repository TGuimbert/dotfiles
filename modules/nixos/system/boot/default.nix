{ config, pkgs, lib, ... }:
with lib;
let cfg = config.tguimbert.system.boot;
in
{
  options.tguimbert.system.boot = {
    secureBoot = mkEnableOption "Wether to enable Secure Boot with Lanzaboote.";
  };

  config = {
    boot.loader.systemd-boot.enable = mkForce (! cfg.secureBoot);

    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.efi.efiSysMountPoint = "/boot";

    boot.bootspec.enable = true;

    boot.tmp.useTmpfs = true;

    boot.initrd.systemd.enable = true;

    boot.lanzaboote = {
      enable = cfg.secureBoot;
      pkiBundle = "/etc/secureboot";
    };

    environment.persistence."/persist-root" = mkIf (cfg.secureBoot && config.tguimbert.impermanence.enable) {
      directories = [
        "/etc/secureboot"
      ];
    };

    environment.systemPackages = with pkgs; mkIf cfg.secureBoot [
      sbctl
    ];
  };
}
