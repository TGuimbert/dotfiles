{ ... }:
{
  nixos.modules.jellyfin =
    {
      config,
      constants,
      lib,
      mediaLibrary,
      mkRouter,
      pkgs,
      ...
    }:
    {
      users = {
        users.jellyfin = {
          # Chosen, not recorded like the older aspects' ids: nixpkgs allocates
          # jellyfin none, and preserved state under a dynamic id stops being
          # readable across a rebuild (../preservation.nix). 350 is ./backup.nix.
          uid = 352;
          # `media` is the load-bearing one. `render`/`video` are belt-and-braces
          # — udev leaves render nodes at 0666, and under the unit's
          # `PrivateUsers` an unmapped supplementary group grants nothing anyway.
          extraGroups = [
            mediaLibrary.group
            "render"
            "video"
          ];
        };
        groups.jellyfin.gid = 352;
      };

      homepageTiles.Services = [
        {
          Jellyfin = {
            icon = "jellyfin.png";
            href = "https://jellyfin.${constants.domain}";
            siteMonitor = "https://jellyfin.${constants.domain}";
            description = "Media server";
          };
        }
      ];

      # A headless host still needs the userspace driver stack for VAAPI. iHD
      # covers the UHD 630 (Gen9.5); the compute runtime is OpenCL, which is
      # what the HDR→SDR tone-mapping filter runs on — without it a 4K HDR file
      # transcoded for a phone comes out grey.
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-compute-runtime
        ];
      };

      services = {
        jellyfin = {
          enable = true;
          hardwareAcceleration = {
            enable = true;
            # VAAPI rather than QSV: on Gen9.5 the QSV path wants the legacy
            # libmfx runtime, while VAAPI + iHD drives the same fixed-function
            # blocks and is the trodden path in nixpkgs.
            type = "vaapi";
            device = "/dev/dri/renderD128";
          };
          # Makes encoding.xml config-as-code: the dashboard's transcoding page
          # is overwritten on every restart (the module backs up what it
          # replaces), so this file is the single source of truth for it.
          forceEncodingConfig = true;
          transcoding = {
            enableHardwareEncoding = true;
            hardwareEncodingCodecs.hevc = true;
            hardwareDecodingCodecs = {
              h264 = true;
              hevc = true;
              hevc10bit = true;
              vp9 = true;
              mpeg2 = true;
              vc1 = true;
            };
          };
        };

        # `mkRouter`, not `mkAutheliaRouter`, and deliberately so: the TV and
        # phone clients cannot complete a browser SSO round trip, so Jellyfin
        # authenticates them itself against LLDAP. That is the reason LLDAP
        # exists — ../../CLAUDE.md, "Authentication on srv-01".
        traefik.dynamicConfigOptions.http = mkRouter {
          name = "jellyfin";
          # Jellyfin's listen port lives in its own network.xml, so there is no
          # option to read it back from.
          port = 8096;
        };
      };

      systemd.services.jellyfin = {
        unitConfig.RequiresMountsFor = [ mediaLibrary.dir ];
        # The module creates these with tmpfiles, which holds on a boot but races
        # on the `switch` that first introduces the preserved dataDir: tmpfiles
        # wins, writes them to the tmpfs root, and preservation's bind mount then
        # hides them — leaving the module's own preStart to die copying
        # encoding.xml into a config/ that is not there.
        preStart = lib.mkBefore ''
          mkdir -p ${config.services.jellyfin.configDir} ${config.services.jellyfin.logDir}
        '';
      };

      preservation.preserveAt."/persistent".directories = [
        {
          directory = config.services.jellyfin.dataDir;
          inherit (config.services.jellyfin) user group;
          mode = "0700";
        }
        {
          # Preserved for where it lands, not for what it holds: `/` is a tmpfs
          # and transcode segments go to <cacheDir>/transcodes, so left out a 4K
          # transcode buffers into RAM.
          directory = config.services.jellyfin.cacheDir;
          inherit (config.services.jellyfin) user group;
          mode = "0700";
        }
      ];
    };
}
