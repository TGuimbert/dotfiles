{ ... }:
{
  # CouchDB, serving one thing: the remote database the Obsidian Self-hosted
  # LiveSync plugin replicates a vault through. Like ./paperless.nix and
  # ./mealie.nix and unlike ./grimmory.nix, an ordinary nixpkgs module — no image
  # tag to pin, no Renovate entry, the weekly lockfile PR covers it.
  nixos.modules.couchdb =
    {
      config,
      constants,
      mkRouter,
      ...
    }:
    let
      port = 5984;
    in
    {
      homepageTiles.Services = [
        {
          CouchDB = {
            icon = "couchdb.png";
            href = "https://couchdb.${constants.domain}/_utils/";
            # `/` answers 401 under require_valid_user below, so the tile would
            # sit permanently red. /_up is the one path left open.
            siteMonitor = "https://couchdb.${constants.domain}/_up";
            description = "Obsidian LiveSync";
          };
        }
      ];

      sops = {
        secrets.couchdbAdminPassword = { };

        # The *server* admin, used only to bootstrap and to maintain — what the
        # plugin carries is a non-admin `_users` account created by hand
        # (../../README.md, "Bringing up CouchDB"). Not `adminPass`, which the
        # module renders into an ini in the *store*: the leak ./mealie.nix and
        # ./shelfmark.nix avoid for their own secrets.
        templates.couchdbAdmins = {
          owner = "couchdb";
          content = ''
            [admins]
            couchdb-admin = ${config.sops.placeholder.couchdbAdminPassword}
          '';
        };
      };

      services = {
        couchdb = {
          enable = true;
          inherit port;
          extraConfigFiles = [ config.sops.templates.couchdbAdmins.path ];

          # Generated but *writable*, the ./sabnzbd.nix shape. The module passes
          # `-couch_ini default.ini <this> <the sops one> /var/lib/couchdb/local.ini`
          # and CouchDB persists runtime changes to the *last* of those, so a
          # Fauxton edit outranks this from then on and a key removed here is not
          # removed from local.ini. Deleting local.ini is the escape hatch.
          extraConfig = {
            couchdb = {
              # Creates _users and _replicator at startup, so no /_cluster_setup.
              single_node = true;
              # LiveSync's requirement; CouchDB's default is 8 MB.
              max_document_size = 50000000;
            };

            chttpd = {
              # CouchDB speaks no LDAP, so unlike ./radicale.nix this cannot
              # delegate to ./lldap.nix — the credential is local to CouchDB.
              require_valid_user = true;
              # Reopens /_up alone, for ./gatus.nix. Both keys are needed:
              # chttpd_auth.erl gates every other path on `RequireValidUser orelse
              # RequireValidUserExceptUp`, and /_up on `RequireValidUser andalso
              # not RequireValidUserExceptUp`.
              require_valid_user_except_for_up = true;
              # Obsidian is a browser origin. Safe alongside the two above:
              # chttpd.erl answers the preflight *before* authenticating, so the
              # credential-less OPTIONS a webview sends is not met with a 401.
              enable_cors = true;
            };

            cors = {
              credentials = true;
              origins = "app://obsidian.md,capacitor://localhost,http://localhost";
              # CouchDB's default is 600.
              max_age = 3600;
            };

            # Otherwise /var/log/couchdb.log, which nothing rotates and which sits
            # on a persistent subvolume.
            log.writer = "journald";
          };

          # Four keys upstream's provisioning script sets are deliberately absent,
          # each checked against couchdb 3.5.1's source: max_http_request_size is
          # already the code default, chttpd_auth.require_valid_user is never read,
          # httpd.WWW-Authenticate only changes the realm string, and
          # cors.headers/cors.methods would *replace* chttpd_cors.erl's built-in
          # lists rather than extend them — which already cover what pouchdb sends.
          # ../../CLAUDE.md has the detail, including what a custom header costs.
        };

        # `mkRouter`, not `mkAutheliaRouter`, joining ./jellyfin.nix and
        # ./radicale.nix: a phone's webview cannot complete a browser SSO round
        # trip, and replication is a REST client besides.
        traefik.dynamicConfigOptions.http = mkRouter {
          name = "couchdb";
          inherit port;
        };
      };

      # No uid pinned, unlike ./mealie.nix and ./radicale.nix: nixpkgs gives
      # couchdb a static id (106).
      preservation.preserveAt."/persistent".directories = [
        {
          directory = "/var/lib/couchdb";
          user = "couchdb";
          group = "couchdb";
          mode = "0750";
        }
      ];
    };
}
