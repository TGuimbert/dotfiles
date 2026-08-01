{ ... }:
{
  nixos.modules.lldap =
    {
      config,
      constants,
      lib,
      ...
    }:
    let
      sopsConfig = {
        group = "lldap-secrets";
        mode = "0440";
      };
    in
    {
      # nixpkgs runs lldap under `DynamicUser`, which allocates a UID per boot —
      # fine for throwaway state, fatal for preserved state, since the next boot
      # cannot read the `server_key` (mode 0400) the last one wrote and systemd
      # will not re-chown a directory preservation has bind-mounted. A static
      # user also makes the `user = "lldap"` below resolve, which it could not
      # while the user lived only for a boot, and moves the state directory from
      # /var/lib/private/lldap to /var/lib/lldap.
      users = {
        users.lldap = {
          isSystemUser = true;
          group = "lldap";
          # Recorded from `getent passwd`, not chosen — see ../preservation.nix.
          uid = 990;
        };
        groups = {
          lldap.gid = 984;
          lldap-secrets = { };
        };
      };

      sops.secrets = {
        lldapEnvironment = sopsConfig;
        lldapUserPass = sopsConfig;
        lldapJwtSecret = sopsConfig;
      };

      systemd.services.lldap.serviceConfig = {
        DynamicUser = lib.mkForce false;
        SupplementaryGroups = "lldap-secrets";
      };
      services = {
        lldap = {
          enable = true;
          environmentFile = config.sops.secrets.lldapEnvironment.path;
          # Via LLDAP_*, not `settings`: the start script bootstraps its own JWT
          # secret unless LLDAP_JWT_SECRET[_FILE] is set (it only checks
          # `settings.jwt_secret`, never `jwt_secret_file`), and the LLDAP_ var it
          # then exports outranks the config file. The pass-file follows suit.
          environment = {
            LLDAP_JWT_SECRET_FILE = config.sops.secrets.lldapJwtSecret.path;
            LLDAP_LDAP_USER_PASS_FILE = config.sops.secrets.lldapUserPass.path;
          };
          settings = {
            ldap_base_dn = "dc=guimbert,dc=fr";
            force_ldap_user_pass_reset = "always";
            ldap_host = "127.0.0.1";
            http_host = "127.0.0.1";
            http_url = "https://ldap.${constants.domain}";
            smtp_options = {
              enable_password_reset = true;
            };
          };
        };
        traefik = {
          staticConfigOptions.entryPoints.ldapsecure.address = ":636";
          dynamicConfigOptions = {
            tcp = {
              routers.lldap = {
                rule = "HostSNI(`ldap.${constants.domain}`)";
                entrypoints = [ "ldapsecure" ];
                service = "lldap-backend";
                tls.certResolver = "cloudflareDns";
              };
              services.lldap-backend.loadBalancer.servers = [ { address = "127.0.0.1:3890"; } ];
            };
            http = {
              routers.lldap = {
                rule = "Host(`ldap.${constants.domain}`)";
                entrypoints = [ "websecure" ];
                service = "lldap";
              };
              services.lldap.loadBalancer.servers = [ { url = "http://127.0.0.1:17170"; } ];
            };
          };
        };
      };
      preservation.preserveAt."/persistent" = {
        directories = [
          {
            # /var/lib/lldap, not /var/lib/private/lldap: the `private`
            # indirection is a DynamicUser mechanism, disabled above.
            directory = "/var/lib/lldap";
            user = "lldap";
            group = "lldap";
            # Matches the module's StateDirectoryMode; 0700 fought it.
            mode = "0750";
          }
        ];
      };
    };
}
