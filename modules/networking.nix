{ ... }:
{
  # Every host declares its own addressing — NetworkManager on the desktops, a
  # static address on srv-01 — so facter's per-interface DHCP would only ever
  # start a dhcpcd competing with it.
  nixos.modules.base.hardware.facter.detected.dhcp.enable = false;

  nixos.modules.desktop =
    { config, pkgs, ... }:
    let
      mkCifs =
        share: extraOptions:
        import ./_hosts/_lib/cifs.nix {
          inherit share extraOptions;
          credentials = config.sops.secrets.smb-secrets.path;
        };
    in
    {
      networking.networkmanager.enable = true;

      sops.secrets.smb-secrets = { };

      fileSystems = {
        "/mnt/private" = mkCifs "private" [ ];
        "/mnt/documents" = mkCifs "documents" [ ];
        "/mnt/shared" = mkCifs "shared" [ ];
        "/mnt/books" = mkCifs "books" [ "nobrl" ];
      };

      environment.systemPackages = [ pkgs.cifs-utils ];
    };
}
