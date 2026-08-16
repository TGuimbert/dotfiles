{ ... }:
{
  # The alert router for srv-01: it polls every route this host (and the NAS)
  # serves, receives heartbeats from the two cron jobs, and turns either kind of
  # failure into a Pushover notification. Deliberately config-as-code — the
  # monitor list is this file, so a restore is a rebuild and there is no state to
  # preserve or stage in ./backup.nix.
  #
  # What it cannot see is srv-01 itself: a monitor sharing a host with the thing
  # it monitors is silent exactly when the host dies. That half is the Beszel hub
  # on the TrueNAS — see ./beszel.nix.
  nixos.modules.gatus =
    {
      config,
      constants,
      lib,
      pkgs,
      mkAutheliaRouter,
      ...
    }:
    let
      port = 8080;
      envFile = config.sops.secrets.gatusEnvironments.path;

      # Almost every route here is `https://<sub>.<domain>` answering 200, so the
      # list below stays a table.
      mkHttps =
        {
          name,
          subdomain ? name,
          path ? "",
          status ? 200,
          conditions ? [ ],
          method ? null,
        }:
        {
          inherit name;
          group = "services";
          url = "https://${subdomain}.${constants.domain}${path}";
          interval = "2m";
          conditions = [ "[STATUS] == ${toString status}" ] ++ conditions;
        }
        // lib.optionalAttrs (method != null) { inherit method; };

      # A route behind the authelia middleware never reaches its backend, and what
      # the middleware answers depends on the request's Accept header: a client
      # accepting HTML gets 302 towards the portal, one sending no Accept header
      # at all gets a bare 401. Gatus is the latter — Go's net/http sets none — so
      # the header is sent deliberately. (curl always sends `Accept: */*` and so
      # reads 302 from the same URL, which makes this easy to misdiagnose.)
      #
      # Refusing the redirect then keeps the recorded status as Authelia's own.
      # Following it would land on the login page and record *its* 200 — green
      # without having touched the service, and still green if the service were
      # dead. Asserting exactly 302 says instead that the route is wired and
      # Authelia is enforcing on it; a 200 would mean it had fallen out from
      # behind the middleware.
      mkAutheliaHttps =
        args:
        mkHttps (args // { status = 302; })
        // {
          client.ignore-redirect = true;
          headers.Accept = "text/html";
        };

      mkIcmp =
        { name, address }:
        {
          inherit name;
          group = "network";
          url = "icmp://${address}";
          interval = "2m";
          conditions = [ "[CONNECTED] == true" ];
        };

      # Reported by a job rather than polled: gatus marks the endpoint failed when
      # the push says so, *and* when no push arrives within `interval`. So one
      # entry covers both "the job broke" and "the job stopped running".
      mkCron =
        { name, interval }:
        {
          inherit name;
          group = "cron";
          token = "\${GATUS_HEARTBEAT_TOKEN}";
          heartbeat = { inherit interval; };
        };

      # `default-alert` below only fills in fields for an endpoint that already
      # declares an alert of that type — it does not attach one. An endpoint
      # written without it would be monitored and never notify, so the attachment
      # is made here for a whole list at once rather than in each builder.
      withPushover = map (endpoint: endpoint // { alerts = [ { type = "pushover"; } ]; });
    in
    {
      homepageTiles.Admin = [
        {
          Gatus = {
            icon = "gatus.png";
            href = "https://gatus.${constants.domain}";
            siteMonitor = "https://gatus.${constants.domain}";
            description = "Uptime checks and alerting";
          };
        }
      ];

      # Same shape as ./homepage.nix: gatus runs under DynamicUser, so the secret
      # is reached through a group rather than an owner — a dynamic user has no
      # passwd entry for sops to chown to.
      users.groups.gatus-secrets = { };
      sops.secrets.gatusEnvironments = {
        group = "gatus-secrets";
        mode = "0440";
      };

      systemd.services = {
        gatus = {
          serviceConfig.SupplementaryGroups = "gatus-secrets";
          # The one alert that cannot travel through gatus, because gatus is the
          # thing that failed.
          onFailure = [ "notify-pushover@gatus.service" ];
        };

        # Backstop only. Everything else reports through gatus, so there is a
        # single place alerting is configured.
        "notify-pushover@" = {
          description = "Notify Pushover that %i failed";
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = envFile;
            ExecStart = "${pkgs.writeShellScript "notify-pushover" ''
              # Pushover truncates at 1024 characters; leave room for the title.
              body=$(${lib.getExe' pkgs.systemd "journalctl"} -u "$1" -n 20 --no-pager -o cat | tail -c 900)
              ${lib.getExe pkgs.curl} -fsS -m 10 --retry 3 --retry-all-errors \
                --form-string "token=$PUSHOVER_TOKEN" \
                --form-string "user=$PUSHOVER_USER_KEY" \
                --form-string "title=srv-01: $1 failed" \
                --form-string "priority=1" \
                --form-string "message=''${body:-no journal output}" \
                https://api.pushover.net/1/messages.json
            ''} %i";
          };
        };
      };

      services = {
        gatus = {
          enable = true;
          environmentFile = envFile;
          settings = {
            web.port = port;

            # Not preserved (see ../preservation.nix): this is derived data, and
            # what it buys is surviving a *restart* — ../auto-upgrade.nix bounces
            # gatus whenever its config changes, and an in-memory store would
            # forget which endpoints were already alerting and re-notify. Losing
            # it on a reboot is fine.
            storage = {
              type = "sqlite";
              path = "/var/lib/gatus/data.db";
            };

            # `${…}` is interpolated by gatus from `environmentFile`, so neither
            # half of the Pushover credential reaches the store.
            alerting.pushover = {
              application-token = "\${PUSHOVER_TOKEN}";
              user-key = "\${PUSHOVER_USER_KEY}";
              default-alert = {
                enabled = true;
                failure-threshold = 3;
                success-threshold = 2;
                send-on-resolved = true;
              };
            };

            endpoints = withPushover [
              (mkHttps {
                name = "authelia";
                subdomain = "auth";
                # Not behind the middleware it provides, so this reaches Authelia
                # itself rather than its portal.
                path = "/api/health";
                # Every route shares the one wildcard from ./traefik.nix, so
                # expiry is asserted here and nowhere else — twelve copies would
                # mean twelve notifications for a single expiry.
                conditions = [ "[CERTIFICATE_EXPIRATION] > 240h" ];
              })
              (mkHttps {
                name = "lldap";
                subdomain = "ldap";
              })
              (mkAutheliaHttps { name = "homepage"; })
              (mkAutheliaHttps { name = "shelfmark"; })
              (mkAutheliaHttps { name = "sonarr"; })
              (mkAutheliaHttps { name = "radarr"; })
              (mkAutheliaHttps { name = "prowlarr"; })
              (mkAutheliaHttps { name = "sabnzbd"; })
              (mkAutheliaHttps { name = "bazarr"; })
              (mkAutheliaHttps { name = "scan"; })
              (mkAutheliaHttps {
                name = "traefik";
                path = "/dashboard/";
              })
              (mkAutheliaHttps {
                name = "traefik-nas";
                path = "/dashboard/";
              })
              (mkHttps { name = "homeassistant"; })
              # Not behind the middleware — it authenticates its own clients —
              # so this reaches Jellyfin itself, and `/health` answers it
              # without a session.
              (mkHttps {
                name = "jellyfin";
                path = "/health";
              })
              # Exempt from the middleware too, so this reaches Jellyseerr
              # itself. `/api/v1/status` is registered ahead of its
              # `isAuthenticated` middleware, so it answers without a session.
              (mkHttps {
                name = "jellyseerr";
                path = "/api/v1/status";
              })
              # Exempt for the same reason as those two. This path answers only
              # once Spring is serving, where `/` would return the login page
              # just as happily from a half-started instance.
              (mkHttps {
                name = "grimmory";
                path = "/api/v1/healthcheck";
              })
              # Exempt from the middleware for the same reason as those three, so
              # this reaches Paperless itself. Its own /api/status/ needs a staff
              # session, which leaves the login page as the unauthenticated proof
              # that Django, PostgreSQL and granian are all up — and it renders
              # only because ./paperless.nix keeps the password login enabled.
              (mkHttps {
                name = "paperless";
                path = "/accounts/login/";
              })
              # Exempt for the same reason again. This path answers without a
              # session, where `/` serves the frontend shell just as happily
              # from an instance whose database is gone.
              (mkHttps {
                name = "mealie";
                path = "/api/app/about";
              })
              # Exempt from the middleware too — its clients speak Basic auth
              # against LLDAP — so this has to reach Radicale's own auth. A GET
              # cannot: `/` redirects to `/.web`, the login UI, which Radicale
              # serves unauthenticated, and following that records its 200 the
              # same way ./homepage.nix's portal would. PROPFIND is the method
              # the DAV clients actually use, and it is refused without
              # credentials, so 401 here says Radicale is serving *and*
              # enforcing where a 200 or a 207 would mean auth had fallen away.
              (mkHttps {
                name = "radicale";
                method = "PROPFIND";
                status = 401;
              })
              # Exempt for the same reason again — its phone clients speak
              # Miniflux's own API. `/healthcheck` is the one of its three
              # unauthenticated health paths that touches PostgreSQL; `/healthz`
              # and `/liveness` would stay green with the database gone.
              (mkHttps {
                name = "miniflux";
                path = "/healthcheck";
                conditions = [ "[BODY] == OK" ];
              })
              # Exempt from the middleware for the same reason again. `/_up` is
              # the one path ./couchdb.nix leaves open, so this needs no
              # credential; asserting the body keeps a 200 from anything other
              # than CouchDB from counting.
              (mkHttps {
                name = "couchdb";
                path = "/_up";
                conditions = [ "[BODY].status == ok" ];
              })
              # Exempt from the middleware for the same reason again. `/api/info`
              # is the one route readeck mounts outside its authenticated router,
              # but it renders from build info alone — so unlike miniflux's
              # `/healthcheck` this stays green with the database gone. There is
              # no unauthenticated path that touches sqlite.
              (mkHttps {
                name = "readeck";
                path = "/api/info";
                conditions = [ "len([BODY].version.release) > 0" ];
              })
              (mkHttps { name = "immich"; })
              (mkHttps {
                name = "garage";
                subdomain = "garage-ui";
              })

              # Only the web UI, which is the half TrueNAS cannot report on
              # itself: a NAS that is down cannot email you that it is down. Pool,
              # SMART and scrub errors are left to its own Email alert service.
              # `/` redirects to `/ui/`, which gatus follows, so a 200 means the
              # UI rendered rather than that nginx merely answered.
              #
              # Not `/api/v2.0/pool`: TrueNAS deprecated REST in 25.04, removes it
              # in 26, and alerts daily about anything still using it. The
              # JSON-RPC replacement needs a login round trip before the query,
              # which a gatus websocket endpoint — one message, one reply — cannot
              # do.
              (mkHttps { name = "truenas"; })

              # Layer 3, so a failure here separates "the box is gone" from
              # "Traefik stopped answering for it".
              (mkIcmp {
                name = "nas";
                address = "10.0.0.55";
              })
              (mkIcmp {
                name = "router";
                address = "10.0.0.1";
              })
            ];

            external-endpoints = withPushover [
              # 01:00 daily (./backup.nix), so a little over a day.
              (mkCron {
                name = "backup-stage";
                interval = "26h";
              })
              # 03:00 daily plus up to 20 min of jitter (../auto-upgrade.nix).
              (mkCron {
                name = "nixos-upgrade";
                interval = "30h";
              })
              # Daily plus up to 5 min of jitter (./recyclarr.nix).
              (mkCron {
                name = "recyclarr";
                interval = "26h";
              })
              # 00:30 daily (./paperless.nix), ahead of ./backup.nix's stage —
              # which copies what this produces, so a silent failure here would
              # leave the backup mirroring a stale export.
              (mkCron {
                name = "paperless-exporter";
                interval = "26h";
              })
            ];
          };
        };

        traefik.dynamicConfigOptions.http = mkAutheliaRouter {
          name = "gatus";
          inherit port;
        };
      };

      # Consumed by ./backup.nix and ../auto-upgrade.nix. Lives here so one file
      # owns the whole heartbeat mechanism; the cost is that a host importing
      # those aspects without this one fails to evaluate, which is the loud
      # failure rather than a job that quietly reports nowhere.
      _module.args.mkHeartbeat = key: {
        # `-` so a secret that failed to decrypt costs the heartbeat rather than
        # the job it is attached to — systemd refuses to start a unit whose
        # EnvironmentFile is missing.
        EnvironmentFile = "-${envFile}";
        ExecStopPost = pkgs.writeShellScript "gatus-heartbeat-${key}" ''
          [ "$SERVICE_RESULT" = success ] && success=true || success=false
          # Straight to the loopback, so the push never meets the authelia
          # middleware. --retry-all-errors covers a refused connection: an
          # upgrade run restarts gatus moments before this fires. `|| true` so a
          # heartbeat that cannot be delivered never fails the job itself — the
          # missing push is already the alert.
          ${lib.getExe pkgs.curl} -fsS -m 10 --retry 5 --retry-all-errors --retry-delay 5 \
            -X POST -H "Authorization: Bearer $GATUS_HEARTBEAT_TOKEN" \
            "http://127.0.0.1:${toString port}/api/v1/endpoints/cron_${key}/external?success=$success" \
            || true
        '';
      };
    };
}
