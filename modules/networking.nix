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
        # One share for the whole media tree — video, books and downloads — so a
        # desktop sees exactly what srv-01 mounts over NFS
        # (server/media-library.nix). The *arr and Grimmory organise it; files
        # get there by being copied in from here.
        "/mnt/media" = mkCifs "media" [ ];
      };

      environment.systemPackages = [ pkgs.cifs-utils ];
    };
}
