{ ... }:
{
  # Recipes and meal planning. Like ./paperless.nix and unlike ./grimmory.nix, an
  # ordinary nixpkgs module: no image tag to pin, no Renovate entry, the weekly
  # lockfile PR covers it.
  nixos.modules.mealie =
    {
      config,
      constants,
      lib,
      mkRouter,
      ...
    }:
    let
      port = 9000;
    in
    {
      # DynamicUser is turned off below, so this account has to exist and keep the
      # same id across boots. 359 is ./print-scan.nix's scanservjs.
      users = {
        users.mealie = {
          isSystemUser = true;
          group = "mealie";
          uid = 360;
        };
        groups.mealie.gid = 360;
      };

      homepageTiles.Services = [
        {
          Mealie = {
            icon = "mealie.png";
            href = "https://mealie.${constants.domain}";
            siteMonitor = "https://mealie.${constants.domain}";
            description = "Recipes and meal planning";
          };
        }
      ];

      sops = {
        # The plaintext half of the pair whose pbkdf2 digest ./authelia.nix reads,
        # declared on the side that needs the real value — ./paperless.nix.
        secrets.autheliaOidcMealieClientSecret.owner = "mealie";

        # Not `settings` below: the module renders that into the unit's
        # `Environment=`, which reaches the store and the journal, exactly as
        # ./shelfmark.nix documents for its API keys.
        templates.mealieEnvironment = {
          owner = "mealie";
          content = ''
            OIDC_CLIENT_SECRET=${config.sops.placeholder.autheliaOidcMealieClientSecret}
          '';
        };
      };

      services = {
        mealie = {
          enable = true;
          inherit port;
          # The module defaults this to 0.0.0.0; Traefik is the only way in.
          listenAddress = "127.0.0.1";
          credentialsFile = config.sops.templates.mealieEnvironment.path;

          # Every value here goes through `toString`, and Nix's `toString false`
          # is the *empty string* — hence the quoted booleans.
          settings = {
            # Mealie derives its OIDC redirect URI from this plus `/login`, which
            # ./authelia.nix registers byte for byte.
            BASE_URL = "https://mealie.${constants.domain}";

            # Its default, stated because it is what keeps account creation gated
            # on the group below rather than on who can reach the port.
            ALLOW_SIGNUP = "false";

            OIDC_AUTH_ENABLED = "true";
            OIDC_PROVIDER_NAME = "Authelia";
            OIDC_CONFIGURATION_URL = "https://auth.${constants.domain}/.well-known/openid-configuration";
            OIDC_CLIENT_ID = "mealie";
            # So the group is the invite: there is no second list to maintain.
            OIDC_SIGNUP_ENABLED = "true";
            # Setting either of these is *also* what appends `groups` to the scope
            # Mealie requests, so dropping them takes the claim with them. The
            # LLDAP groups are created by hand — ../../README.md.
            OIDC_USER_GROUP = "mealie-users";
            OIDC_ADMIN_GROUP = "mealie-admins";
            # Off for ./paperless.nix's reason: the local login is the way in when
            # Authelia is the thing that is down.
            OIDC_AUTO_REDIRECT = "false";
          };
        };

        # `mkRouter`, not `mkAutheliaRouter`: Mealie has no proxy-header auth mode
        # to delegate to the way the *arr do, and its REST API is a client no
        # browser SSO round trip can serve.
        traefik.dynamicConfigOptions.http = mkRouter {
          name = "mealie";
          inherit port;
        };
      };

      systemd.services.mealie.serviceConfig = {
        # Same reason as ./lldap.nix and ./shelfmark.nix: a uid allocated per boot
        # cannot own preserved state. It also moves the state out of
        # /var/lib/private/mealie.
        DynamicUser = lib.mkForce false;
        User = "mealie";
        Group = "mealie";
        StateDirectoryMode = "0700";
      };

      # Holds the recipes and their images, and the app secret Mealie generates on
      # first start and signs its tokens with.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = "/var/lib/mealie";
          user = "mealie";
          group = "mealie";
          mode = "0700";
        }
      ];
    };
}
