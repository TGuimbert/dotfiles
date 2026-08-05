{ ... }:
{
  # The request front end: the household asks for a film or a series here rather
  # than touching Sonarr and Radarr directly.
  #
  # nixpkgs renamed the module to `services.seerr` (it serves Plex and Emby too
  # now), so the unit is `seerr.service` while the aspect, route, tile and state
  # directory keep the Jellyseerr name.
  nixos.modules.jellyseerr =
    {
      config,
      constants,
      lib,
      mkRouter,
      ...
    }:
    {
      users = {
        # DynamicUser is turned off below, so this account has to exist and keep
        # the same id across boots.
        users.jellyseerr = {
          isSystemUser = true;
          group = "jellyseerr";
          # 355 is ./bazarr.nix.
          uid = 356;
        };
        groups.jellyseerr.gid = 356;
      };

      homepageTiles.Services = [
        {
          Jellyseerr = {
            icon = "jellyseerr.png";
            href = "https://jellyseerr.${constants.domain}";
            siteMonitor = "https://jellyseerr.${constants.domain}";
            description = "Media requests";
          };
        }
      ];

      services = {
        seerr.enable = true;

        # `mkRouter`, not `mkAutheliaRouter`, by extension from ./jellyfin.nix:
        # it authenticates against Jellyfin, so the middleware would mean an
        # Authelia account per household member and two logins from a phone.
        traefik.dynamicConfigOptions.http = mkRouter {
          name = "jellyseerr";
          inherit (config.services.seerr) port;
        };
      };

      systemd.services.seerr = {
        # The module sets only PORT, so without this it listens on every
        # interface. Undocumented but real: the bundle reads `process.env.HOST`
        # and passes it to `.listen(port, host)`.
        environment.HOST = "127.0.0.1";
        serviceConfig = {
          # Same reason as ./lldap.nix and prowlarr in ./servarr.nix: a uid
          # allocated per boot cannot own preserved state. Turning it off also
          # moves the state out of /var/lib/private.
          DynamicUser = lib.mkForce false;
          User = "jellyseerr";
          Group = "jellyseerr";
        };
      };

      # Hardcoded rather than derived from `configDir`: the module picks that and
      # StateDirectory together off `system.stateVersion` (25.11 here, so
      # /var/lib/jellyseerr/config), and they stop sharing a parent at 26.05.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = "/var/lib/jellyseerr";
          user = "jellyseerr";
          group = "jellyseerr";
          mode = "0700";
        }
      ];
    };
}
