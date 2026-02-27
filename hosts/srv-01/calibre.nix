{ config, ... }:
let
  smbMount = "/mnt/books";
in
{
  sops.secrets.smb-secrets = { };
  services = {
    calibre-web = {
      enable = true;
      dataDir = "/var/lib/calibre-web";
      options = {
        calibreLibrary = "${smbMount}/library";
        enableBookUploading = true;
        enableBookConversion = true;
        enableKepubify = true;
        reverseProxyAuth = {
          enable = true;
          header = "Remote-User";
        };
      };
    };
    traefik.dynamicConfigOptions = {
      http = {
        routers.calibre = {
          rule = "Host(`calibre.home.guimbert.fr`)";
          entrypoints = [ "websecure" ];
          middlewares = [ "authelia" ];
          service = "calibre";
        };
        services.calibre.loadBalancer.servers = [
          { url = "http://localhost:${toString config.services.calibre-web.listen.port}"; }
        ];
      };
    };
  };
  environment.persistence."/persistent" = {
    directories = [
      {
        directory = config.services.calibre-web.dataDir;
        user = config.services.calibre-web.user;
        group = config.services.calibre-web.group;
        mode = "0700";
      }
    ];
  };
  fileSystems.books = {
    mountPoint = smbMount;
    device = "//nas.lan/books";
    fsType = "cifs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nobrl"
      "x-systemd.idle-timeout=60"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "credentials=${config.sops.secrets.smb-secrets.path}"
      "uid=${config.services.calibre-web.user}"
      "gid=${config.services.calibre-web.group}"
    ];
  };
  systemd.services.calibre-web = {
    after = [ "mnt-books.mount" ];
    requires = [ "mnt-books.mount" ];
  };
}
