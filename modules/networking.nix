{ ... }:
{
  nixos.modules.desktop =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      networking = {
        networkmanager.enable = true;
        useDHCP = lib.mkDefault true;
      };

      sops.secrets.smb-secrets = { };

      fileSystems =
        let
          automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
        in
        {
          "/mnt/private" = {
            device = "//nas.lan/private";
            fsType = "cifs";
            options = [
              "${automount_opts},credentials=${config.sops.secrets.smb-secrets.path},uid=1000,gid=100"
            ];
          };
          "/mnt/documents" = {
            device = "//nas.lan/documents";
            fsType = "cifs";
            options = [
              "${automount_opts},credentials=${config.sops.secrets.smb-secrets.path},uid=1000,gid=100"
            ];
          };
          "/mnt/shared" = {
            device = "//nas.lan/shared";
            fsType = "cifs";
            options = [
              "${automount_opts},credentials=${config.sops.secrets.smb-secrets.path},uid=1000,gid=100"
            ];
          };
          "/mnt/books" = {
            device = "//nas.lan/books";
            fsType = "cifs";
            options = [
              "${automount_opts},credentials=${config.sops.secrets.smb-secrets.path},uid=1000,gid=100"
              "nobrl"
            ];
          };
        };

      environment.systemPackages = [ pkgs.cifs-utils ];
    };
}
