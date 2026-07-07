{ ... }:
{
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

      # NetworkManager owns DHCP; facter's detection would start dhcpcd
      # on the same interfaces.
      hardware.facter.detected.dhcp.enable = false;

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
