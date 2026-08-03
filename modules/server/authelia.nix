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
          # Load-bearing for every `{{ secret "…" }}` below *and* for the JWKS
          # fragment the module templates out of `oidcIssuerPrivateKeyFile`. The
          # module sets this itself for the JWKS case, but `environmentVariables`
          # merges last and wins — same value, so no conflict. Do not drop it.
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
              # 4.39 still counts a passkey as *one* factor, which is exactly what
              # the `one_factor` rules below ask for — so a passkey alone opens
              # the forward-auth routes, no password. It is deliberately not
              # enough for the `two_factor` OIDC client below. Making one satisfy
              # `two_factor` is `experimental_enable_passkey_uv_two_factors`, left
              # off while it carries that prefix.
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
            # The second way in, for apps that speak OIDC rather than the
            # forward-auth middleware below — ./traefik-router.nix only helps apps
            # with no login of their own. ./lldap.nix stays for the third kind,
            # which speak neither: Jellyfin's OIDC plugin was
            # archived upstream in May 2026 and never completed outside a browser,
            # so LDAP remains the only credential its TV clients can use.
            #
            # The issuer key and HMAC secret are wired through the module's
            # `secrets` block above, not named here.
            identity_providers.oidc = {
              # Authelia refuses to start with an empty client list, so this is
              # not optional scaffolding — the provider needs a real client.
              clients = [
                {
                  client_id = "immich";
                  client_name = "Immich";
                  client_secret = "{{ secret \"${config.sops.secrets.autheliaOidcImmichClientSecretDigest.path}\" }}";
                  public = false;
                  # Stricter than the `one_factor` access_control rules below.
                  # Since a passkey counts as one factor in 4.39, this asks for a
                  # password *plus* a second factor — a passkey alone will not
                  # open Immich the way it opens the forward-auth routes.
                  authorization_policy = "two_factor";
                  # Immich's own integration doc. `false` permits PKCE rather
                  # than forbidding it, so Immich may still send a challenge.
                  require_pkce = false;
                  response_types = [ "code" ];
                  grant_types = [ "authorization_code" ];
                  id_token_signed_response_alg = "RS256";
                  # Immich wants userinfo as a signed JWT, not plain JSON.
                  userinfo_signed_response_alg = "RS256";
                  # Immich reads the secret from the POST body, not Basic auth.
                  token_endpoint_auth_method = "client_secret_post";
                  redirect_uris = [
                    "https://immich.${constants.domain}/auth/login"
                    "https://immich.${constants.domain}/user-settings"
                    # Deep link for the mobile app, which has no browser to
                    # return to.
                    "app.immich:///oauth-callback"
                  ];
                  # Immich's doc also shows an `immich_scope` backed by a
                  # `claims_policy`, carrying `immich_quota` and `immich_role`.
                  # Both are omitted: they only seed those fields when Immich
                  # first creates a user and are never resynced afterwards, and
                  # LLDAP holds no attribute to populate them from. Adding them
                  # means defining `definitions.user_attributes` expressions —
                  # worth doing only if roles should come from LDAP groups.
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
