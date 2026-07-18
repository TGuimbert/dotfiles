{ ... }:
{
  nixos.modules.authelia =
    { config, constants, ... }:
    let
      sopsConfig = {
        owner = config.services.authelia.instances.main.user;
        group = config.services.authelia.instances.main.group;
      };
    in
    {
      sops = {
        secrets = {
          autheliaJwtSecret = sopsConfig;
          autheliaStorageEncryptionKey = sopsConfig;
          autheliaSessionSecret = sopsConfig;
          autheliaSmtpAddress = sopsConfig;
          autheliaSmtpUsername = sopsConfig;
          autheliaSmtpSender = sopsConfig;
          autheliaSmtpPassword = sopsConfig;
          autheliaLdapPassword = sopsConfig;
        };
      };
      services = {
        authelia.instances.main = {
          enable = true;
          environmentVariables.X_AUTHELIA_CONFIG_FILTERS = "template";
          secrets = {
            jwtSecretFile = config.sops.secrets.autheliaJwtSecret.path;
            storageEncryptionKeyFile = config.sops.secrets.autheliaStorageEncryptionKey.path;
            sessionSecretFile = config.sops.secrets.autheliaSessionSecret.path;
          };
          settings = {
            theme = "auto";
            server = {
              endpoints.authz.forward-auth = {
                implementation = "ForwardAuth";
                authn_strategies = [
                  { name = "HeaderAuthorization"; }
                  { name = "CookieSession"; }
                ];
              };
              address = "tcp4://:9091";
            };
            identity_validation.elevated_session.require_second_factor = true;
            totp = {
              disable = false;
              issuer = "${constants.domain}";
            };
            password_policy.zxcvbn = {
              enabled = true;
              min_score = 4;
            };
            authentication_backend.ldap = {
              implementation = "lldap";
              address = "ldap://localhost:3890";
              base_dn = "dc=guimbert,dc=fr";
              user = "UID=authelia,OU=people,DC=guimbert,DC=fr";
              password = "{{ secret \"${config.sops.secrets.autheliaLdapPassword.path}\" }}";
            };
            access_control = {
              default_policy = "deny";
              rules = [
                {
                  domain = "*.${constants.domain}";
                  policy = "one_factor";
                }
              ];
            };
            session = {
              name = "authelia_session";
              cookies = [
                {
                  domain = "${constants.domain}";
                  authelia_url = "https://auth.${constants.domain}";
                }
              ];
            };
            regulation = {
              max_retries = 4;
              find_time = "3m";
              ban_time = "5m";
            };
            storage.local.path = "/var/lib/authelia-main/db.sqlite3";
            notifier.smtp = {
              address = "{{ secret \"${config.sops.secrets.autheliaSmtpAddress.path}\" }}";
              username = "{{ secret \"${config.sops.secrets.autheliaSmtpUsername.path}\" }}";
              sender = "{{ secret \"${config.sops.secrets.autheliaSmtpSender.path}\" }}";
              password = "{{ secret \"${config.sops.secrets.autheliaSmtpPassword.path}\" }}";
            };
          };
        };
        traefik.dynamicConfigOptions = {
          http = {
            routers.authelia = {
              rule = "Host(`auth.${constants.domain}`)";
              entrypoints = [ "websecure" ];
              service = "authelia";
            };
            services.authelia.loadBalancer.servers = [ { url = "http://localhost:9091"; } ];
            middlewares.authelia.forwardAuth = {
              address = "http://localhost:9091/api/authz/forward-auth";
              trustForwardHeader = true;
              authResponseHeaders = "Remote-User,Remote-Groups,Remote-Name,Remote-Email";
            };
          };
        };
      };

      preservation.preserveAt."/persistent" = {
        directories = [
          "/var/lib/authelia-main/"
        ];
      };
    };
}
