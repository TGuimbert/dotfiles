{ ... }:
{
  nixos.modules.desktop =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      mkCifs =
        share: extraOptions:
        import ./_hosts/_lib/cifs.nix {
          inherit share extraOptions;
          credentials = config.sops.secrets.smb-secrets.path;
        };
    in
    {
      networking = {
        networkmanager.enable = true;
        useDHCP = lib.mkDefault true;
      };

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
