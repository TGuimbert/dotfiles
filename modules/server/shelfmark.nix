{ ... }:
{
  # Search, request and download for books — what ./grimmory.nix deliberately
  # does not do. To the book library what ./jellyseerr.nix is to the video one,
  # except that it also drives the downloader, there being no Readarr to hand
  # releases to.
  #
  # It reuses this host's Prowlarr and SABnzbd rather than bringing its own, so
  # this aspect will not evaluate without `servarr` and `sabnzbd` — the same
  # deliberate loud failure as `mediaLibrary` and `homepageTiles`.
  nixos.modules.shelfmark =
    {
      config,
      constants,
      lib,
      mediaLibrary,
      mkAutheliaRouter,
      ...
    }:
    let
      port = 8084;
    in
    {
      users = {
        users.shelfmark = {
          isSystemUser = true;
          group = "shelfmark";
          # DynamicUser is turned off below, so this account has to exist and
          # keep the same id across boots. 357 is ./grimmory.nix.
          uid = 358;
          extraGroups = [ mediaLibrary.group ];
        };
        groups.shelfmark.gid = 358;
      };

      homepageTiles.Services = [
        {
          Shelfmark = {
            icon = "shelfmark.png";
            href = "https://shelfmark.${constants.domain}";
            siteMonitor = "https://shelfmark.${constants.domain}";
            description = "Book search and requests";
          };
        }
      ];

      # The keys stay single-copy in sops and the env lines are *rendered* from
      # them, for the reason ./servarr.nix gives: two copies of a credential
      # drift. They cannot go in `services.shelfmark.environment` — the module
      # renders that into the unit's `Environment=`, which reaches both the store
      # and the journal.
      sops.templates.shelfmarkEnvironment = {
        owner = "shelfmark";
        content = ''
          PROWLARR_API_KEY=${config.sops.placeholder.prowlarrApiKey}
          SABNZBD_API_KEY=${config.sops.placeholder.sabnzbdApiKey}
        '';
      };

      services = {
        shelfmark = {
          enable = true;
          environment = {
            FLASK_PORT = port;
            SESSION_COOKIE_SECURE = "true";

            # Delegated wholesale to the Authelia middleware in front, which is
            # the header contract calibre-web used to carry: `Remote-User` is
            # what ../server/authelia.nix's `authResponseHeaders` sets, so that
            # list stays load-bearing after calibre-web's removal.
            AUTH_METHOD = "proxy";
            PROXY_AUTH_USER_HEADER = "Remote-User";
            PROXY_AUTH_LOGOUT_URL = "https://auth.${constants.domain}/logout";

            # Indexers and Usenet backbones stay configured once, in Prowlarr and
            # ./sabnzbd.nix. Reached on the loopback, so neither is exempted from
            # the middleware to serve this.
            PROWLARR_ENABLED = "true";
            PROWLARR_URL = "http://127.0.0.1:${toString config.services.prowlarr.settings.server.port}";
            PROWLARR_USENET_CLIENT = "sabnzbd";
            SABNZBD_URL = "http://127.0.0.1:${toString config.services.sabnzbd.settings.misc.port}";
            # The category ./sabnzbd.nix declares; its completed directory is in
            # the same export as the bookdrop below.
            SABNZBD_CATEGORY = "books";

            # Hands finished books to Grimmory by writing into the folder it
            # imports from. `rename`, not `organize`: upstream is explicit that
            # a folder-creating template must not target an ingest folder, and
            # Grimmory does its own filing once the book is in the library.
            BOOKS_OUTPUT_MODE = "folder";
            INGEST_DIR = mediaLibrary.books.bookdrop;
            FILE_ORGANIZATION = "rename";

            # Both, because a book has no Bazarr to add French afterwards the way
            # ./recyclarr.nix's English-only profiles rely on.
            BOOK_LANGUAGE = "en,fr";

            # A link back to the library in Shelfmark's nav bar. The variable
            # keeps its Calibre-Web name upstream but takes any library's URL.
            CALIBRE_WEB_URL = "https://grimmory.${constants.domain}";
          };
        };

        # A browser-only front end, so the same treatment as the *arr — and
        # unlike ./grimmory.nix, which is exempt because its device clients
        # cannot follow an SSO redirect.
        traefik.dynamicConfigOptions.http = mkAutheliaRouter {
          name = "shelfmark";
          inherit port;
        };
      };

      systemd.services.shelfmark = {
        unitConfig.RequiresMountsFor = [ mediaLibrary.dir ];
        serviceConfig = {
          EnvironmentFile = [ config.sops.templates.shelfmarkEnvironment.path ];

          # Same reason as ./lldap.nix and prowlarr in ./servarr.nix: a uid
          # allocated per boot cannot own preserved state. Turning it off also
          # moves the state out of /var/lib/private/shelfmark.
          DynamicUser = lib.mkForce false;
          User = "shelfmark";
          Group = "shelfmark";
          StateDirectoryMode = "0700";

          # Off because it breaks this rather than hardens it: as ./jellyfin.nix
          # notes, a supplementary group outside the unit's uid map grants
          # nothing, so `media` would buy nothing and every write into the
          # bookdrop would fail.
          PrivateUsers = lib.mkForce false;

          # Load-bearing for the reason ./servarr.nix spells out. The module sets
          # 0077, stricter than the *arr's 0022 and failing the same way.
          UMask = lib.mkForce "0002";

          # `ProtectSystem = "strict"` leaves the hierarchy readable but
          # read-only — right for SABnzbd's completed downloads, wrong for the
          # one directory this writes.
          ReadWritePaths = [ mediaLibrary.books.bookdrop ];
        };
      };

      # Settings that are not expressible as environment variables, the user
      # table and the request history — none of it reproducible, so ./backup.nix
      # stages it too. Read back rather than restated, as ./backup.nix does.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = config.services.shelfmark.environment.CONFIG_DIR;
          user = "shelfmark";
          group = "shelfmark";
          mode = "0700";
        }
      ];
    };
}
