{ ... }:
{
  # Calendars and contacts, authenticating against LLDAP rather than sitting
  # behind the authelia middleware: CalDAV and CardDAV clients send HTTP Basic
  # and cannot complete a browser SSO round trip — ./jellyfin.nix's argument on
  # different clients. An ordinary nixpkgs module, so the ./mealie.nix shape
  # rather than the ./grimmory.nix one.
  nixos.modules.radicale =
    {
      config,
      constants,
      mkRouter,
      ...
    }:
    let
      # Radicale's own default, matched rather than restated: declaring
      # `server.hosts` is what turns off the module's IPAddressAllow=localhost /
      # IPAddressDeny=any, which it keys off that option being *absent*.
      port = 5232;
    in
    {
      # nixpkgs allocates radicale's uid dynamically, so it is pinned for
      # ./lldap.nix's reason: a uid allocated per boot cannot own preserved
      # state. 360 is ./mealie.nix.
      users = {
        users.radicale.uid = 361;
        groups.radicale.gid = 361;
      };

      homepageTiles.Services = [
        {
          Radicale = {
            icon = "radicale.png";
            href = "https://radicale.${constants.domain}";
            siteMonitor = "https://radicale.${constants.domain}";
            description = "Calendars and contacts";
          };
        }
      ];

      # `owner` rather than a supplementary group: the module's unit runs with
      # `PrivateUsers`, which ./jellyfin.nix explains costs such a group
      # everything.
      sops.secrets.radicaleLdapPassword.owner = "radicale";

      services = {
        radicale = {
          enable = true;
          settings = {
            auth = {
              # Stated because Radicale 3.5.0 changed the default from `none` to
              # `denyall`, and the module asserts the key rather than let a host
              # come up refusing everyone.
              type = "ldap";
              ldap_uri = "ldap://127.0.0.1:3890";
              # `ou=people`, not the root DN: LLDAP evaluates `memberOf` as a
              # *person* attribute, and a search based anywhere else logs
              # `Ignoring unknown group attribute "memberof" in filter` and
              # matches nothing — surfacing only as a 401 for every user.
              ldap_base = "ou=people,dc=guimbert,dc=fr";
              # LLDAP refuses anonymous search and Radicale always looks up the
              # user's DN before binding as them, so this account is required.
              # Created by hand in `lldap_strict_readonly` — ../../README.md.
              ldap_reader_dn = "uid=radicale,ou=people,dc=guimbert,dc=fr";
              ldap_secret_file = config.sops.secrets.radicaleLdapPassword.path;
              # Gates access on a group the way ./mealie.nix does. The value has
              # to be the group's full DN; `cn=radicale-users` alone matches
              # nothing.
              ldap_filter = "(&(objectClass=person)(uid={0})(memberOf=cn=radicale-users,ou=groups,dc=guimbert,dc=fr))";
              # The login Radicale keeps once the bind succeeds, and so what
              # fixes the collection path under `owner_only`. Without it the path
              # is whatever the client typed, and a differently-cased login gets
              # a second, empty tree.
              ldap_user_attribute = "uid";
              # Two LDAP binds per request otherwise, and DAV clients poll. The
              # expiry defaults are left alone (15s success, 90s failure), so
              # dropping someone from the group still takes effect in seconds.
              cache_logins = true;
            };

            # Radicale's default, stated because ./gatus.nix's 401 rests on it
            # refusing an empty user — the `/.web` login UI is served without
            # credentials, so this is what keeps the collections behind them.
            rights.type = "owner_only";
          };
        };

        # `mkRouter`, not `mkAutheliaRouter` — forward-auth in front of a DAV
        # endpoint would lock out every client this exists for.
        traefik.dynamicConfigOptions.http = mkRouter {
          name = "radicale";
          inherit port;
        };
      };

      # 0750 matches the module's StateDirectoryMode, and its
      # `StateDirectory=radicale/collections` creates the child at service start
      # — so this is immune to the tmpfiles race ../../CLAUDE.md documents.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = "/var/lib/radicale";
          user = "radicale";
          group = "radicale";
          mode = "0750";
        }
      ];
    };
}
