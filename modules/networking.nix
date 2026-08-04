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
        # The library srv-01 mounts over NFS (server/media-library.nix). The
        # *arr organise it; the files get there by being copied in from here.
        "/mnt/video" = mkCifs "video" [ ];
      };

      environment.systemPackages = [ pkgs.cifs-utils ];
    };
}
