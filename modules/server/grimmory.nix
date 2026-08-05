{ ... }:
{
  # The ebook, comic and audiobook library, replacing calibre-web. It owns the
  # files on disk — move, rename, delete and the BookDrop import ./shelfmark.nix
  # feeds — which is what the CIFS mount calibre-web used could not carry, and
  # why ./media-library.nix exports books and video from one dataset.
  #
  # The one container on this host: Grimmory is Spring Boot plus Angular,
  # published only as an image and requiring MariaDB, so there is no nixpkgs path
  # for it. ../../CLAUDE.md, "Books on srv-01", for what that costs.
  nixos.modules.grimmory =
    {
      config,
      constants,
      lib,
      mediaLibrary,
      mkRouter,
      pkgs,
      ...
    }:
    let
      port = 6060;
      stateDir = "/var/lib/grimmory";
      database = "grimmory";
    in
    {
      users = {
        users.grimmory = {
          isSystemUser = true;
          group = "grimmory";
          # Chosen rather than recorded — this account is new, and nothing in
          # nixpkgs allocates for a container. 356 is ./jellyseerr.nix.
          uid = 357;
          # The account exists to own the preserved data dir; the container's own
          # identity comes from USER_ID/GROUP_ID below, which podman applies
          # without consulting the host's group file.
          extraGroups = [ mediaLibrary.group ];
        };
        groups.grimmory.gid = 357;
      };

      homepageTiles.Services = [
        {
          Grimmory = {
            icon = "booklore.png";
            href = "https://grimmory.${constants.domain}";
            siteMonitor = "https://grimmory.${constants.domain}/api/v1/healthcheck";
            description = "Ebook and audiobook library";
          };
        }
      ];

      # Plaintext, not a digest: it is handed to MariaDB in the grant below and
      # to the container in its environment, and both need the real value.
      sops = {
        secrets.grimmoryDbPassword.owner = "mysql";
        templates = {
          # Applied on every boot rather than at database creation, so it is also
          # what makes a restore deterministic — `initialScript` would run once,
          # against a data dir that a restore brings back already initialised.
          grimmoryDbGrant = {
            owner = "mysql";
            content = ''
              CREATE USER IF NOT EXISTS '${database}'@'127.0.0.1'
                IDENTIFIED BY '${config.sops.placeholder.grimmoryDbPassword}';
              ALTER USER '${database}'@'127.0.0.1'
                IDENTIFIED BY '${config.sops.placeholder.grimmoryDbPassword}';
              GRANT ALL PRIVILEGES ON `${database}`.* TO '${database}'@'127.0.0.1';
            '';
          };
          grimmoryEnvironment.content = ''
            DATABASE_URL=jdbc:mariadb://127.0.0.1:3306/${database}
            DATABASE_USERNAME=${database}
            DATABASE_PASSWORD=${config.sops.placeholder.grimmoryDbPassword}
          '';
        };
      };

      services = {
        mysql = {
          enable = true;
          package = pkgs.mariadb;
          ensureDatabases = [ database ];
          # `ensureUsers` is deliberately unused: it identifies users with
          # unix_socket, which authenticates the *OS* user connecting over the
          # socket. The container connects over TCP, where that plugin can never
          # match — hence the password grant templated above.
          settings.mysqld = {
            # The container shares this host's network namespace, so loopback is
            # the whole of the database's reachable surface.
            bind-address = "127.0.0.1";
            # Real 4-byte UTF-8. MariaDB still defaults to `utf8mb3`, which
            # cannot hold every character a book title can.
            character-set-server = "utf8mb4";
            collation-server = "utf8mb4_unicode_ci";
          };
        };

        # `mkRouter`, not `mkAutheliaRouter`, for ./jellyfin.nix's reason: the
        # OPDS feed, Kobo sync and the KOReader plugin cannot complete a browser
        # SSO round trip, so Grimmory authenticates them itself — against
        # Authelia's OIDC rather than LDAP, since it speaks OIDC natively.
        # ../../CLAUDE.md, "Authentication on srv-01".
        traefik.dynamicConfigOptions.http = mkRouter {
          name = "grimmory";
          inherit port;
        };
      };

      virtualisation = {
        # Only what running a service in a container needs. Deliberately *not*
        # ../podman.nix: that aspect is workstation tooling — it writes a
        # minikube config through home-manager and preserves tguimbert's
        # *rootless* image store, which is not the one this uses.
        podman.enable = true;
        oci-containers = {
          backend = "podman";
          containers.grimmory = {
            # Pinned, never `latest`: ../auto-upgrade.nix rebuilds this host
            # nightly, and a floating tag would make what runs here depend on
            # when podman last pulled. Renovate bumps it — see
            # ../../.github/renovate.json.
            image = "ghcr.io/grimmory-tools/grimmory:v3.2.4";
            environmentFiles = [ config.sops.templates.grimmoryEnvironment.path ];
            environment = {
              USER_ID = toString config.users.users.grimmory.uid;
              # The *primary* group, so files land group-owned by `media`
              # whatever the umask does to the mode.
              GROUP_ID = toString config.users.groups.${mediaLibrary.group}.gid;
              TZ = config.time.timeZone;
              BOOKLORE_PORT = toString port;
              SWAGGER_ENABLED = "false";
              # `NETWORK` is upstream's guard for a mount that cannot rename, and
              # it disables the UI's move, rename and delete — the exact
              # operations this replacement exists to enable. Ours can rename:
              # ./media-library.nix puts library and bookdrop in one filesystem.
              DISK_TYPE = "LOCAL";
            };
            volumes = [
              "${stateDir}:/app/data"
              "${mediaLibrary.books.library}:/books"
              "${mediaLibrary.books.bookdrop}:/bookdrop"
            ];
            extraOptions = [
              # Saves a bridge, a published port and a second address for
              # MariaDB to listen on: it stays on the loopback and Traefik
              # reaches :6060 there. The cost is that Grimmory binds 6060 on
              # every interface, and the firewall is what keeps it off the LAN —
              # the same trade ./bazarr.nix documents.
              "--network=host"
              # Load-bearing for the reason ./servarr.nix spells out: under 0022
              # a new directory lands group `r-x` against the NAS's default ACL,
              # and the next writer cannot enter it.
              "--umask=0002"
            ];
          };
        };
      };

      systemd.services = {
        grimmory-db = {
          description = "Grant Grimmory its MariaDB user";
          after = [ "mysql.service" ];
          requires = [ "mysql.service" ];
          before = [ "podman-grimmory.service" ];
          requiredBy = [ "podman-grimmory.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # MariaDB's superuser is the `mysql` OS user, not root: the module
            # identifies it with unix_socket, which matches on who is connecting.
            User = "mysql";
            Group = "mysql";
          };
          script = "${lib.getExe' config.services.mysql.package "mysql"} -u mysql < ${config.sops.templates.grimmoryDbGrant.path}";
        };

        podman-grimmory = {
          # Two of the volumes are inside the export, so without this the
          # container starts against empty directories on the tmpfs root.
          unitConfig.RequiresMountsFor = [ mediaLibrary.dir ];
        };
      };

      preservation.preserveAt."/persistent".directories = [
        {
          # Covers, reader state and logs. The library metadata is in MariaDB,
          # not here — ./backup.nix stages both.
          directory = stateDir;
          user = "grimmory";
          inherit (mediaLibrary) group;
          mode = "0750";
        }
        {
          directory = config.services.mysql.dataDir;
          inherit (config.services.mysql) user group;
          mode = "0700";
        }
        {
          # The image store, and not optional: `/` is a tmpfs, so without this
          # every boot re-pulls a few hundred megabytes of Java into RAM.
          directory = "/var/lib/containers";
          mode = "0700";
        }
      ];
    };
}
