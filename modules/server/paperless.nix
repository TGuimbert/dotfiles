{ ... }:
{
  # The paperwork archive: scan or drop a document in, get it OCR'd, tagged and
  # searchable. What ./grimmory.nix is to books and ./jellyfin.nix is to video.
  #
  # Unusually for this host it is an ordinary nixpkgs module — no image tag to
  # pin, no Renovate `customManagers` entry, no container. ../../CLAUDE.md,
  # "Documents on srv-01".
  nixos.modules.paperless =
    {
      config,
      constants,
      lib,
      mkHeartbeat,
      mkRouter,
      requirePostgresql,
      ...
    }:
    let
      inherit (config.services.paperless) consumptionDir dataDir;
    in
    {
      # The cluster below is preserved by ./postgresql.nix, not here; taking its
      # argument is what makes a host importing this aspect without that one fail
      # to evaluate.
      assertions = [ (requirePostgresql "paperless") ];

      # `dataDir` is preserved at 0750 below, and 0777 on the consume directory
      # buys nothing without search permission on the way to it — so the one
      # writer gets the group rather than the archive getting 0755. Without this
      # the scanservjs action fails with EACCES on a directory `ls` shows as
      # world-writable.
      #
      # `mkIf` at the attrset level, not on `extraGroups`: defining any attribute
      # under `users.users.scanservjs` would declare the account on a host that
      # has this aspect and no scanner.
      users.users = lib.mkIf config.services.scanservjs.enable {
        scanservjs.extraGroups = [ config.users.users.paperless.group ];
      };

      homepageTiles.Services = [
        {
          Paperless = {
            icon = "paperless-ngx.png";
            href = "https://paperless.${constants.domain}";
            siteMonitor = "https://paperless.${constants.domain}";
            description = "Document archive";
          };
        }
      ];

      sops = {
        secrets = {
          paperlessAdminPassword.owner = "paperless";
          # The plaintext half of the pair whose pbkdf2 digest ./authelia.nix
          # reads. Declared here rather than there because this is the side that
          # needs the real value, and `sops.placeholder` only resolves for a
          # secret that some module has declared.
          autheliaOidcPaperlessClientSecret.owner = "paperless";
        };
        templates.paperlessEnvironment = {
          owner = "paperless";
          # Carries the client secret, so it cannot go in `settings` — the module
          # renders that into the unit's `Environment=`, which reaches the store
          # and the journal, exactly as ./shelfmark.nix documents for its keys.
          #
          # Single-quoted because systemd's EnvironmentFile parser strips a
          # value's surrounding double quotes and would eat the JSON's.
          #
          # `provider_id` fixes the callback path
          # `/accounts/oidc/authelia/login/callback/`, which ./authelia.nix lists
          # byte for byte; a mismatch shows up only as an invalid redirect.
          content = ''
            PAPERLESS_SOCIALACCOUNT_PROVIDERS='{"openid_connect":{"SCOPE":["openid","profile","email"],"APPS":[{"provider_id":"authelia","name":"Authelia","client_id":"paperless","secret":"${config.sops.placeholder.autheliaOidcPaperlessClientSecret}","settings":{"server_url":"https://auth.${constants.domain}/.well-known/openid-configuration"}}]}}'
          '';
        };
      };

      services = {
        paperless = {
          enable = true;
          # Sets PAPERLESS_URL, and nothing else — `configureNginx` is off by
          # default. That is what puts this host in Django's
          # CSRF_TRUSTED_ORIGINS and ALLOWED_HOSTS behind Traefik.
          domain = "paperless.${constants.domain}";
          # Rather than the default sqlite: four units (granian plus three celery
          # processes) write concurrently, which is where sqlite starts returning
          # "database is locked". The exporter below is what keeps the engine
          # invisible to ./backup.nix.
          database.createLocally = true;
          # Bootstraps the superuser so there is an account to link the OIDC
          # identity onto — allauth deliberately does not auto-link by email.
          passwordFile = config.sops.secrets.paperlessAdminPassword.path;
          environmentFile = config.sops.templates.paperlessEnvironment.path;

          # The module's own knob for the 0777 the scanservjs action needs; a
          # shared group cannot work, because paperless's units run with
          # `PrivateUsers` and ./jellyfin.nix explains what that costs a
          # supplementary group.
          consumptionDirIsPublic = true;

          # Upstream's own backup mechanism, and the reason ./backup.nix stages
          # no database dump. Ahead of its 01:00 run, and clear of the
          # 03:00-05:00 window ../auto-upgrade.nix may reboot in.
          exporter = {
            enable = true;
            onCalendar = "00:30";
          };

          settings = {
            # Has to match the LLDAP account the OIDC identity gets linked to, or
            # the bootstrap creates a superuser nobody can log in as.
            PAPERLESS_ADMIN_USER = "tguimbert";
            # Narrows tesseract's language set, so changing it is a rebuild.
            PAPERLESS_OCR_LANGUAGE = "fra+eng";

            PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
            # Without this any Authelia user self-provisions an account; only
            # already-linked ones may sign in.
            PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = false;

            # Traefik reaches granian over plain HTTP on the loopback, so without
            # this Django thinks the request is insecure and drops `Secure` from
            # the session cookie.
            PAPERLESS_PROXY_SSL_HEADER = [
              "HTTP_X_FORWARDED_PROTO"
              "https"
            ];

            # PAPERLESS_DISABLE_REGULAR_LOGIN and PAPERLESS_REDIRECT_LOGIN_TO_SSO
            # are deliberately left off: the password login is the way in when
            # Authelia is the thing that is down, and it is what makes
            # /accounts/login/ a meaningful 200 for ./gatus.nix.
          };
        };

        # `mkRouter`, not `mkAutheliaRouter`, for ./jellyfin.nix's reason: the
        # mobile app and API tokens cannot complete a browser SSO round trip, so
        # Paperless authenticates its own clients — against Authelia's OIDC.
        traefik.dynamicConfigOptions.http = mkRouter {
          name = "paperless";
          inherit (config.services.paperless) port;
        };

        # Contributed here so ./print-scan.nix knows nothing about Paperless:
        # `extraActions` is a list, so definitions concatenate across modules —
        # the ./homepage.nix collector idiom on an option upstream provides. On a
        # host with no scanner it is simply never rendered, so unlike
        # ./media-library.nix this wants no loud failure.
        #
        # A copy, not a move: the scan stays in the scanservjs inbox, so filing
        # the wrong page costs nothing.
        scanservjs.extraActions = [
          ''
            {
              name: 'Send to Paperless',
              async execute(fileInfo) {
                // Not scanservjs's own `Process` helper: the nixpkgs module
                // renders config.local.js into the store, where upstream's
                // `require.resolve('./server/classes/process', …)` resolves
                // nothing. Node builtins resolve from anywhere.
                require('fs').copyFileSync(
                  fileInfo.fullname,
                  '${consumptionDir}/' + fileInfo.name);
              }
            }
          ''
        ];
      };

      # Attached here rather than in ./backup.nix because this aspect owns the
      # unit; the cost is that `paperless` without `gatus` fails to evaluate.
      systemd.services.paperless-exporter.serviceConfig = mkHeartbeat "paperless-exporter";

      # No uid pinning, unlike every sibling aspect: nixpkgs allocates paperless
      # statically (`ids.uids.paperless = 315`), so it already survives a
      # rebuild. PostgreSQL is preserved by ./postgresql.nix, which owns the
      # cluster this shares with ./miniflux.nix. Redis is absent on purpose: a
      # celery broker, the same reasoning as ./gatus.nix's unpreserved sqlite
      # store.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = dataDir;
          user = "paperless";
          group = "paperless";
          mode = "0750";
        }
      ];
    };
}
