{ ... }:
{
  # Bookmarks and read-later: article extraction, highlights, labels,
  # collections, EPUB export and an OPDS catalogue. The ./miniflux.nix shape —
  # an ordinary nixpkgs module, one unit, one sqlite file — rather than the
  # ./grimmory.nix one, with a single exception: ../nixpkgs.nix takes the
  # *package* from unstable, because 26.05 carries 0.22.3 and the OIDC support
  # this file is written against arrived in 0.23.
  # ../../CLAUDE.md, "Read-later on srv-01".
  nixos.modules.readeck =
    {
      config,
      constants,
      lib,
      mkRouter,
      ...
    }:
    let
      # Next after ./miniflux.nix's 8087, rather than readeck's own default 8000.
      port = 8088;
      baseUrl = "https://readeck.${constants.domain}";
      stateDir = "/var/lib/readeck";
    in
    {
      # nixpkgs runs readeck under DynamicUser (forced off below), so the uid is
      # pinned for ./lldap.nix's reason: a uid allocated per boot cannot own
      # preserved state. 361 is ./radicale.nix.
      users = {
        users.readeck = {
          isSystemUser = true;
          group = "readeck";
          uid = 362;
        };
        groups.readeck.gid = 362;
      };

      homepageTiles.Services = [
        {
          Readeck = {
            icon = "readeck.png";
            href = baseUrl;
            siteMonitor = baseUrl;
            description = "Bookmarks and read-later";
          };
        }
      ];

      sops = {
        secrets = {
          readeckSecretKey = { };
          # The plaintext half of the pair whose pbkdf2 digest ./authelia.nix
          # reads, declared on the side that needs the real value.
          autheliaOidcReadeckClientSecret = { };
        };

        # Root-owned, like ./miniflux.nix's: PID 1 reads `EnvironmentFile=`
        # before dropping privileges. Neither value can go in `settings` below,
        # which the module renders into the store.
        #
        # The secret key is not optional. Readeck derives its session, token and
        # TOTP keys from it and, left empty, generates one and writes it back
        # into the config file — which here is a store path. Supplying it is what
        # stops readeck writing at all, and so what makes the unstable package on
        # 26.05's module safe. `…_PROVIDERS_0_…` merges into the provider at
        # index 0 below rather than appending a second one.
        templates.readeckEnvironment.content = ''
          READECK_SECRET_KEY=${config.sops.placeholder.readeckSecretKey}
          READECK_AUTH_OIDC_PROVIDERS_0_CLIENT_SECRET=${config.sops.placeholder.autheliaOidcReadeckClientSecret}
        '';
      };

      systemd.services.readeck.serviceConfig = {
        # ./mealie.nix's reason: it would otherwise put the state below in
        # /var/lib/private/readeck, owned by a uid allocated per boot.
        DynamicUser = lib.mkForce false;
        User = "readeck";
        Group = "readeck";
      };

      services = {
        readeck = {
          enable = true;
          environmentFile = config.sops.templates.readeckEnvironment.path;

          settings = {
            # Defaults to the relative "data" under the unit's WorkingDirectory,
            # so stating it keeps the database and the `bookmarks/` archives in
            # the one preserved directory. ./backup.nix stages both.
            main.data_directory = stateDir;

            server = {
              host = "127.0.0.1";
              inherit port;
              # Required, not cosmetic: readeck builds its OIDC redirect URI as
              # `<base_url>/login/oidc`, and without this it takes the base from
              # the proxy headers — so the URI ./authelia.nix registers could not
              # be guaranteed to match.
              base_url = baseUrl;
            };

            auth.oidc.providers = [
              {
                name = "Authelia";
                # The *issuer*, like ./miniflux.nix's, so neither the
                # /.well-known/openid-configuration suffix nor a trailing slash.
                # Unlike Miniflux it is resolved lazily, so a wrong value fails
                # at the first login and leaves a clean journal until then.
                url = "https://auth.${constants.domain}";
                client_id = "readeck";
                # client_secret is deliberately absent; see the sops template.

                # Safe only because it is not the gate: ./authelia.nix refuses
                # anyone outside `readeck-users` before the flow reaches here.
                provisioning = true;

                # A role map, not an access list — an identity matching nothing
                # here still gets in, as `user`. First match wins, so the admins
                # entry must come first; and it is re-applied on every login, so
                # removing an entry demotes the accounts it covered.
                groups = [
                  [
                    "readeck-admins"
                    "admin"
                  ]
                  [
                    "readeck-users"
                    "user"
                  ]
                ];
              }
            ];
          };
        };

        # `mkRouter`, not `mkAutheliaRouter`, joining ./jellyfin.nix and the rest:
        # readeck authenticates its own clients, and the Bearer tokens its
        # extension and OPDS readers carry would be rejected by the forward-auth
        # middleware, whose `HeaderAuthorization` strategy reads that same header.
        traefik.dynamicConfigOptions.http = mkRouter {
          name = "readeck";
          inherit port;
        };
      };

      preservation.preserveAt."/persistent".directories = [
        {
          directory = stateDir;
          user = "readeck";
          group = "readeck";
          mode = "0750";
        }
      ];
    };
}
