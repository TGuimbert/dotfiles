{ ... }:
{
  nixos.modules.calibre =
    {
      config,
      constants,
      mkAutheliaRouter,
      ...
    }:
    let
      smbMount = "/mnt/books";
    in
    {
      # Recorded from `getent passwd`, not chosen — see ../preservation.nix.
      users = {
        users.calibre-web.uid = 997;
        groups.calibre-web.gid = 997;
      };

      homepageTiles.Services = [
        {
          Calibre = {
            icon = "calibre-web.png";
            href = "https://calibre.${constants.domain}";
            siteMonitor = "https://calibre.${constants.domain}";
            description = "Ebook library";
          };
        }
      ];

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
        traefik.dynamicConfigOptions.http = mkAutheliaRouter {
          name = "calibre";
          port = config.services.calibre-web.listen.port;
        };
      };
      preservation.preserveAt."/persistent" = {
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
      }
      // import ../_hosts/_lib/cifs.nix {
        share = "books";
        credentials = config.sops.secrets.smb-secrets.path;
        uid = config.services.calibre-web.user;
        gid = config.services.calibre-web.group;
        extraOptions = [ "nobrl" ];
      };
      systemd.services.calibre-web = {
        after = [ "mnt-books.mount" ];
        requires = [ "mnt-books.mount" ];
      };
    };
}
