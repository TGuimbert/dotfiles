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
            directory = "/var/lib/private/lldap/";
            user = "lldap";
            group = "lldap";
            mode = "0700";
          }
        ];
      };
    };
}
