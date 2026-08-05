{ ... }:
{
  # Subtitles for the library ./servarr.nix fills. It writes `.srt` *beside*
  # each video rather than into a store of its own, which is why it needs the
  # same library access and UMask the *arr do — and why Jellyfin then finds the
  # subtitles with no configuration at all.
  #
  # ./recyclarr.nix syncs the plain English profiles, so releases are chosen for
  # availability rather than language: this is the piece that supplies French.
  nixos.modules.bazarr =
    {
      config,
      constants,
      mediaLibrary,
      mkAutheliaRouter,
      ...
    }:
    {
      users = {
        users.bazarr = {
          # Pinned like jellyfin's and prowlarr's: the module's `isSystemUser`
          # has no static id, so the preserved state below would stop being
          # readable across a rebuild (../preservation.nix). 354 is ./sabnzbd.nix.
          uid = 355;
          extraGroups = [ mediaLibrary.group ];
        };
        groups.bazarr.gid = 355;
      };

      homepageTiles.Services = [
        {
          Bazarr = {
            icon = "bazarr.png";
            href = "https://bazarr.${constants.domain}";
            siteMonitor = "https://bazarr.${constants.domain}";
            description = "Subtitle manager";
          };
        }
      ];

      services = {
        bazarr.enable = true;

        # Browser-only admin UI, so the same treatment as the *arr — except that
        # this one cannot be held to the loopback from here: Bazarr reads its
        # listen address from `general.ip` in its own config and the module
        # passes only `--port`, so it answers on every interface until that is
        # set in the UI. The firewall is what keeps it off the LAN meanwhile.
        traefik.dynamicConfigOptions.http = mkAutheliaRouter {
          name = "bazarr";
          port = config.services.bazarr.listenPort;
        };
      };

      systemd.services.bazarr = {
        # Merges with the module's own `[ dataDir ]` rather than colliding with
        # it: `unitOption` concatenates list-valued definitions.
        unitConfig.RequiresMountsFor = [ mediaLibrary.dir ];
        # Load-bearing for the reason spelled out in ./servarr.nix. The module
        # sets no UMask, so no mkForce.
        serviceConfig.UMask = "0002";
      };

      # Language profiles, provider logins and the history of what was already
      # fetched — none of it reproducible, so ./backup.nix stages it too.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = config.services.bazarr.dataDir;
          inherit (config.services.bazarr) user group;
          mode = "0700";
        }
      ];
    };
}
