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
