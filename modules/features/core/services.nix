{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.features.services.enable = lib.mkEnableOption "common services" // {
    default = true;
  };

  config = lib.mkIf config.features.services.enable {
    services = {
      openssh.enable = true;
      printing.enable = true;
      fwupd.enable = true;
      pcscd.enable = true;
      btrfs.autoScrub.enable = true;
      avahi.nssmdns4 = true;
      tailscale = {
        enable = true;
        useRoutingFeatures = "client";
        extraSetFlags = [
          "--operator=tguimbert"
        ];
      };
    };

    sops = {
      defaultSopsFile = ../../../secrets/common.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gnome
      ];
    };

    environment.systemPackages = [ pkgs.qemu ];
  };
}
