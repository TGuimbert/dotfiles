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
      # Recorded from `getent passwd`, not chosen — see ../preservation.nix.
      users = {
        users.authelia-main.uid = 999;
        groups.authelia-main.gid = 999;
      };

      homepageTiles.Services = [
        {
          Authelia = {
            icon = "authelia.png";
            href = "https://auth.${constants.domain}";
            siteMonitor = "https://auth.${constants.domain}";
            description = "Authentication management";
          };
        }
      ];

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
          autheliaOidcIssuerPrivateKey = sopsConfig;
          autheliaOidcHmacSecret = sopsConfig;
          # Only the digest is read by this host. The plaintext half lives beside
          # it so the app it belongs to can be configured later without minting a
          # new pair — `sops -d --extract '["autheliaOidcImmichClientSecret"]'`.
          autheliaOidcImmichClientSecretDigest = sopsConfig;
        };
      };
      services = {
        authelia.instances.main = {
          enable = true;
          # Required by every `{{ secret "…" }}` below, and by the JWKS fragment
          # the module templates out of `oidcIssuerPrivateKeyFile`.
          environmentVariables.X_AUTHELIA_CONFIG_FILTERS = "template";
          secrets = {
            jwtSecretFile = config.sops.secrets.autheliaJwtSecret.path;
            storageEncryptionKeyFile = config.sops.secrets.autheliaStorageEncryptionKey.path;
            sessionSecretFile = config.sops.secrets.autheliaSessionSecret.path;
            oidcHmacSecretFile = config.sops.secrets.autheliaOidcHmacSecret.path;
            oidcIssuerPrivateKeyFile = config.sops.secrets.autheliaOidcIssuerPrivateKey.path;
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
            webauthn = {
              disable = false;
              display_name = "${constants.domain}";
              # 4.39 counts a passkey as *one* factor, so it satisfies the
              # `one_factor` rules below but not the `two_factor` OIDC client.
              # `experimental_enable_passkey_uv_two_factors` would change that; it
              # is off because its own schema says it WILL be removed, and an
              # unknown key is a startup error on a host that upgrades unattended.
              enable_passkey_login = true;
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
            # For apps that authenticate their own users rather than sitting
            # behind the forward-auth middleware below. Why LLDAP stays alongside
            # this: ../../CLAUDE.md, "Authentication on srv-01".
            identity_providers.oidc = {
              # Authelia will not start with an empty client list.
              clients = [
                {
                  client_id = "immich";
                  client_name = "Immich";
                  client_secret = "{{ secret \"${config.sops.secrets.autheliaOidcImmichClientSecretDigest.path}\" }}";
                  public = false;
                  # Stricter than the `one_factor` access_control rules below, so
                  # a passkey alone does not open Immich.
                  authorization_policy = "two_factor";
                  # Left unset, `consent_mode` resolves to `explicit` and prompts
                  # on every login. Pre-configured rather than `implicit` because
                  # the stored grant is matched with HasExactGrants — a client
                  # asking for *wider* scopes than were approved gets a consent
                  # screen, which `implicit` would grant silently. The long
                  # duration keeps that check while making the prompt a
                  # once-a-year event. Stored in `oauth2_consent_preconfiguration`,
                  # so it outlives a restart even though the session does not.
                  consent_mode = "pre-configured";
                  pre_configured_consent_duration = "1 year";
                  # Permits PKCE rather than forbidding it; Immich may still send
                  # a challenge.
                  require_pkce = false;
                  response_types = [ "code" ];
                  grant_types = [ "authorization_code" ];
                  id_token_signed_response_alg = "RS256";
                  # Both algorithms have to match Immich's own settings, and
                  # Immich defaults this one to `none` — a mismatch fails login
                  # with nothing useful in the logs.
                  userinfo_signed_response_alg = "RS256";
                  token_endpoint_auth_method = "client_secret_post";
                  redirect_uris = [
                    "https://immich.${constants.domain}/auth/login"
                    "https://immich.${constants.domain}/user-settings"
                    "app.immich:///oauth-callback"
                  ];
                  # Immich's doc also shows an `immich_scope` carrying
                  # `immich_quota` and `immich_role`. Omitted: Immich reads them
                  # only when it first creates a user, and LLDAP holds no
                  # attribute to fill them from.
                  scopes = [
                    "openid"
                    "profile"
                    "email"
                  ];
                }
              ];
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
          # Ownership spelled out for the same reason as ./traefik.nix.
          {
            directory = "/var/lib/authelia-main";
            inherit (config.services.authelia.instances.main) user group;
            mode = "0700";
          }
        ];
      };
    };
}
