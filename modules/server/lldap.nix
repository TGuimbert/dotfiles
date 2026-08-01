{ ... }:
{
  nixos.modules.lldap =
    { config, constants, ... }:
    let
      sopsConfig = {
        group = "lldap-secrets";
        mode = "0440";
      };
    in
    {
      users.groups.lldap-secrets = { };
      sops.secrets = {
        lldapEnvironment = sopsConfig;
        lldapUserPass = sopsConfig;
        lldapJwtSecret = sopsConfig;
      };
      systemd.services.lldap.serviceConfig.SupplementaryGroups = "lldap-secrets";
      services = {
        lldap = {
          enable = true;
          environmentFile = config.sops.secrets.lldapEnvironment.path;
          # Passed as LLDAP_-prefixed variables rather than through `settings`,
          # which is where the module's own example puts them. The start script
          # bootstraps a JWT secret when neither LLDAP_JWT_SECRET_FILE nor
          # LLDAP_JWT_SECRET is set — and it guards on `settings.jwt_secret`, not
          # `settings.jwt_secret_file`, so setting the latter does not prevent it.
          # The bootstrap then exports LLDAP_JWT_SECRET_FILE=./jwt_secret_file,
          # and LLDAP_ variables take priority over the config file, silently
          # replacing the sops path with one relative to WorkingDirectory:
          #   Could not open `./jwt_secret_file` ...: Permission denied
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
            directory = "/var/lib/private/lldap/";
            user = "lldap";
            group = "lldap";
            mode = "0700";
          }
        ];
      };
    };
}
