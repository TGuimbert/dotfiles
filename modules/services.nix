{ ... }:
{
  nixos.modules.desktop =
    { pkgs, ... }:
    {
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
        defaultSopsFile = ../secrets/common.yaml;
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      };

      xdg.portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gnome
        ];
      };

      hardware.keyboard.qmk.enable = true;

      environment.systemPackages = with pkgs; [
        qemu
      ];
    };
}
