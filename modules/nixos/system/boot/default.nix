{ lib, ... }:
with lib;
{
  boot = {
    loader = {
      systemd-boot.enable = mkDefault true;

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };

    bootspec.enable = true;
    tmp.useTmpfs = true;
    initrd.systemd.enable = true;
  };
}
