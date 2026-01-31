{ config, ... }:
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
      settings = {
        ldap_base_dn = "dc=guimbert,dc=fr";
        ldap_user_pass_file = config.sops.secrets.lldapUserPass.path;
        force_ldap_user_pass_reset = "always";
        ldap_host = "127.0.0.1";
        http_host = "127.0.0.1";
        http_url = "https://ldap.home.guimbert.fr";
        jwt_secret_file = config.sops.secrets.lldapJwtSecret.path;
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
            rule = "HostSNI(`ldap.home.guimbert.fr`)";
            entrypoints = [ "ldapsecure" ];
            service = "lldap-backend";
            tls.certResolver = "cloudflareDns";
          };
          services.lldap-backend.loadBalancer.servers = [ { address = "127.0.0.1:3890"; } ];
        };
        http = {
          routers.lldap = {
            rule = "Host(`ldap.home.guimbert.fr`)";
            entrypoints = [ "websecure" ];
            service = "lldap";
          };
          services.lldap.loadBalancer.servers = [ { url = "http://127.0.0.1:17170"; } ];
        };
      };
    };
  };
  environment.persistence."/persistent" = {
    directories = [
      {
        directory = "/var/lib/private/lldap/";
        user = "lldap";
        group = "lldap";
        mode = "0700";
      }
    ];
  };
}
