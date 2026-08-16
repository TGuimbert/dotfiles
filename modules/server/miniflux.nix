{ ... }:
{
  # The news reader: RSS and Atom, which is what Reddit, YouTube and most news
  # sites publish natively, so nothing here manufactures feeds. An ordinary
  # nixpkgs module, the ./paperless.nix shape rather than the ./grimmory.nix one.
  # ../../CLAUDE.md, "News on srv-01".
  nixos.modules.miniflux =
    {
      config,
      constants,
      mkRouter,
      requirePostgresql,
      ...
    }:
    let
      # Stated rather than defaulted: LISTEN_ADDR's own default is
      # localhost:8080, which is ./gatus.nix's port.
      port = 8087;
      baseUrl = "https://miniflux.${constants.domain}";
    in
    {
      # Miniflux has no sqlite mode and nothing on disk — feeds, entries, users,
      # API keys and the OIDC link are all rows — so its whole state is the
      # cluster ./postgresql.nix preserves and ./backup.nix dumps. Hence also no
      # preservation entry and no pinned uid here.
      assertions = [ (requirePostgresql "miniflux") ];

      homepageTiles.Services = [
        {
          Miniflux = {
            icon = "miniflux.png";
            href = baseUrl;
            siteMonitor = baseUrl;
            description = "News and RSS reader";
          };
        }
      ];

      sops = {
        secrets = {
          # Six characters minimum, or the module's CREATE_ADMIN path refuses to
          # create the account.
          minifluxAdminPassword = { };
          # The plaintext half of the pair whose pbkdf2 digest ./authelia.nix
          # reads, declared on the side that needs the real value.
          autheliaOidcMinifluxClientSecret = { };
        };

        # `adminCredentialsFile` is the module's *only* EnvironmentFile hook, so
        # both secrets travel through it. Neither can go in `config` below, which
        # the module renders into the unit's `Environment=` — the store and the
        # journal, as ./shelfmark.nix notes. Left root-owned, unlike every
        # sibling here: the unit runs with DynamicUser, so there is no account to
        # chown to, and PID 1 reads EnvironmentFile before dropping privileges.
        templates.minifluxEnvironment.content = ''
          ADMIN_USERNAME=tguimbert
          ADMIN_PASSWORD=${config.sops.placeholder.minifluxAdminPassword}
          OAUTH2_CLIENT_SECRET=${config.sops.placeholder.autheliaOidcMinifluxClientSecret}
        '';
      };

      services = {
        miniflux = {
          # `createDatabaseLocally` defaults on, declaring the role and the
          # database in ./postgresql.nix's cluster and ordering this after it.
          enable = true;
          adminCredentialsFile = config.sops.templates.minifluxEnvironment.path;

          # Freeform `str`/`int` only: the module coerces a bool for
          # CREATE_ADMIN, RUN_MIGRATIONS and WATCHDOG alone, so `false` anywhere
          # else would be `toString false`, the empty string.
          config = {
            BASE_URL = baseUrl;
            LISTEN_ADDR = "127.0.0.1:${toString port}";

            OAUTH2_PROVIDER = "oidc";
            OAUTH2_CLIENT_ID = "miniflux";
            OAUTH2_OIDC_PROVIDER_NAME = "Authelia";
            # The *issuer*, not the discovery document ./mealie.nix points at:
            # go-oidc appends /.well-known/openid-configuration itself, then
            # compares the issuer it gets back byte for byte. So that suffix and
            # a trailing slash both break it — at startup, not at first login.
            OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://auth.${constants.domain}";
            # Miniflux serves GET /oauth2/{provider}/callback, and ./authelia.nix
            # registers this URL byte for byte; a mismatch is reported only as an
            # invalid redirect.
            OAUTH2_REDIRECT_URL = "${baseUrl}/oauth2/oidc/callback";
            # Its default, and ./paperless.nix's stance: the Authelia identity is
            # *linked* onto an existing account, so nobody self-provisions one.
            OAUTH2_USER_CREATION = 0;

            # DISABLE_LOCAL_AUTH is left off for ./paperless.nix's and
            # ./mealie.nix's reason: the password login is the way in when
            # Authelia is the thing that is down.
          };
        };

        # `mkRouter`, not `mkAutheliaRouter`, joining ./jellyfin.nix and the
        # rest: the phone clients speak Miniflux's own API — or the Fever and
        # Google Reader ones it also serves — and cannot complete a browser SSO
        # round trip.
        traefik.dynamicConfigOptions.http = mkRouter {
          name = "miniflux";
          inherit port;
        };
      };
    };
}
