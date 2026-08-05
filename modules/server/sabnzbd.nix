{ ... }:
{
  # The downloader ./servarr.nix was missing: Sonarr and Radarr hand a release to
  # SABnzbd, it fetches, repairs and unpacks it, and they rename what comes out
  # into the library. Usenet only — no torrent client, so nothing here seeds and
  # nothing needs a hardlink to keep a file alive after import.
  #
  # Where the two directories live is the load-bearing decision. Incomplete is
  # local: par2 repair and unrar rewrite the same bytes several times, which
  # belongs on the NVMe rather than on the far side of NFS. Complete is *inside*
  # the library export, so a finished file crosses the network exactly once and
  # the *arr import is a rename within one filesystem rather than a copy. A
  # separate `downloads` dataset on the NAS would undo that — a different dataset
  # is a different filesystem, and rename(2) would fall back to a copy.
  nixos.modules.sabnzbd =
    {
      config,
      constants,
      lib,
      mediaLibrary,
      mkAutheliaRouter,
      ...
    }:
    let
      # 8080 is ./gatus.nix, which sabnzbd would otherwise collide with.
      port = 8085;
      stateDir = "/var/lib/sabnzbd";
      completeDir = "${mediaLibrary.dir}/downloads";

      # Name → subdirectory of completeDir. Sonarr and Radarr name one of these
      # when they hand over a release. The `*` entry is the default and has to
      # exist. (`pp = 3` below is repair + unpack + delete; priority -100 means
      # "inherit the default category's".)
      categories = {
        "*" = "";
        tv = "tv";
        movies = "movies";
      };

      # Placeholder in the generated ini → the sops key holding its value. One
      # table rather than two lists, so a secret cannot be declared without also
      # being substituted — which would leave the `@…@` literal in the config.
      secrets = {
        "@sabnzbd_api_key@" = "sabnzbdApiKey";
        "@sabnzbd_nzb_key@" = "sabnzbdNzbKey";
        "@unlimited_host@" = "sabnzbdUnlimitedHost";
        "@unlimited_username@" = "sabnzbdUnlimitedUsername";
        "@unlimited_password@" = "sabnzbdUnlimitedPassword";
        "@block_host@" = "sabnzbdBlockHost";
        "@block_username@" = "sabnzbdBlockUsername";
        "@block_password@" = "sabnzbdBlockPassword";
      };
    in
    {
      users = {
        users.sabnzbd = {
          # Pinned like jellyfin's and prowlarr's: nixpkgs commented sabnzbd out
          # of ids.nix ahead of 26.05, so `isSystemUser` would take a per-boot
          # uid and the preserved state below would stop being readable
          # (../preservation.nix). 353 is ./servarr.nix's prowlarr.
          uid = 354;
          # The export squashes every request to media:media, but the client
          # kernel still checks locally against the ownership it is shown — as
          # in ./servarr.nix.
          extraGroups = [ mediaLibrary.group ];
        };
        groups.sabnzbd.gid = 354;
      };

      homepageTiles.Services = [
        {
          SABnzbd = {
            icon = "sabnzbd.png";
            href = "https://sabnzbd.${constants.domain}";
            siteMonitor = "https://sabnzbd.${constants.domain}";
            description = "Usenet downloader";
          };
        }
      ];

      # Owned by sabnzbd because the module's preStart — which reads them through
      # `replace-secret` — runs under `User=sabnzbd`, not root.
      sops.secrets = lib.genAttrs (lib.attrValues secrets) (_: {
        owner = "sabnzbd";
      });

      services = {
        sabnzbd = {
          enable = true;

          # Both of these switch on `system.stateVersion`, not on the nixpkgs
          # release: below 26.05 they default the legacy way — `configFile` to a
          # mutable path, which makes everything in `settings` ignored outright.
          # This host is pinned at 25.11 and stays there, so they are stated
          # rather than inherited.
          configFile = null;
          # Writable, but still generated from here: the module merges the
          # existing file *under* the generated one, so every key below wins on
          # each activation. What it buys is silence — SABnzbd tries to save its
          # config every 30s, and against a read-only file each attempt logs
          # `Cannot write to INI file`, which buried the errors that mattered.
          # (`misc.config_lock` does not help; only the web UI reads it, while
          # save_config() checks is_writable() unconditionally.) The cost is that
          # a key *removed* from this file is no longer removed from the ini.
          allowConfigWrite = true;

          # `secretValues` keeps the whole structure here and substitutes only
          # the values at start, where `secretFiles` would move a second ini
          # fragment into sops. The hosts are placeholders like the credentials:
          # which providers these are belongs in sops, not in a public repo.
          secretValues = lib.mapAttrs (_: key: config.sops.secrets.${key}.path) secrets;

          settings = {
            misc = {
              # Traefik is the only way in: bound to loopback, and `openFirewall`
              # left at its default false, as in ./servarr.nix.
              host = "127.0.0.1";
              inherit port;

              # Pinned rather than generated: SABnzbd invents both on first start
              # and writes them back, so a restore or a wiped ini would hand the
              # *arr a key that no longer works.
              api_key = "@sabnzbd_api_key@";
              nzb_key = "@sabnzbd_nzb_key@";

              # Anti-DNS-rebinding check: SABnzbd refuses a Host header that is
              # neither localhost nor an IP unless it is listed here, which is
              # every request arriving through Traefik. Without it the UI answers
              # "Access denied" behind a perfectly working router.
              host_whitelist = "sabnzbd.${constants.domain}";

              download_dir = "${stateDir}/incomplete";
              complete_dir = completeDir;

              # Pauses the queue instead of filling the disk the nix store shares.
              # Only the incomplete side needs it; the NAS reports its own
              # capacity through TrueNAS' alert service.
              download_free = "25G";

              # Well under SABnzbd's "25% of memory" advice: `/` is a tmpfs here
              # and already claims 25% (../_hosts/srv-01/disks.nix).
              cache_limit = "512M";
            };

            # Built from the table above so the sections here and the
            # directories created in preStart cannot drift apart.
            categories = lib.mapAttrs (name: dir: {
              pp = "3";
              script = "None";
              priority = if name == "*" then 0 else -100;
              inherit dir;
            }) categories;

            # Section keys are ids, not hostnames: SABnzbd connects using `host`
            # and ignores `name` entirely (sabnzbd/config.py, ConfigServer), so
            # nothing here names the provider — that is all in sops.
            #
            # Two backbones, because one is a single point of *availability*: a
            # 430 for an article is final, and an 82%-missing release is what a
            # takedown looks like from the client side. Split by role, which is
            # what sets the priorities.
            servers = {
              # Flat-rate, so it goes first (priority 0 is highest). Worth
              # keeping on a different backbone from the block — a second
              # reseller of the same spool would fail on the same articles.
              unlimited = {
                name = "unlimited";
                displayname = "Unlimited";
                enable = true;
                host = "@unlimited_host@";
                port = 563;
                ssl = true;
                username = "@unlimited_username@";
                password = "@unlimited_password@";
                # Adjust to whatever the account actually allows.
                connections = 30;
                priority = 0;
                # Wait for it rather than declare articles missing on a
                # transient failure — it is meant to serve nearly everything.
                required = true;
              };
              # Metered, so it is spent only on the articles `unlimited` returned
              # 430 for. `required = false` so a block that has run out is
              # skipped rather than stalling the queue behind it.
              block = {
                name = "block";
                displayname = "Block";
                host = "@block_host@";
                port = 563;
                ssl = true;
                username = "@block_username@";
                password = "@block_password@";
                # The account allows 50 across every client using it.
                connections = 20;
                priority = 1;
                required = false;
              };
            };
          };
        };

        # A browser-only admin UI, so the same treatment as the *arr. Sonarr and
        # Radarr are unaffected: they reach the API on the loopback, behind the
        # middleware rather than through it, so nothing needs exempting the way
        # ./jellyfin.nix does.
        traefik.dynamicConfigOptions.http = mkAutheliaRouter {
          name = "sabnzbd";
          inherit port;
        };
      };

      systemd.services.sabnzbd = {
        unitConfig.RequiresMountsFor = [ mediaLibrary.dir ];

        # SABnzbd only creates a category's directory when a job first completes
        # into it, and until then Sonarr and Radarr fail RemotePathMappingCheck
        # with "…cannot see this directory. You may need to adjust the folder's
        # permissions" — which reads as a permissions fault and is not one.
        preStart = lib.mkAfter ''
          mkdir -p ${
            lib.escapeShellArgs (
              map (dir: if dir == "" then completeDir else "${completeDir}/${dir}") (lib.attrValues categories)
            )
          }
        '';

        # Load-bearing for the same reason as ./servarr.nix: a directory created
        # under 0022 lands group `r-x` on the NAS and the *arr cannot move the
        # finished download out of it. The module sets no UMask, so no mkForce.
        serviceConfig.UMask = "0002";
      };

      # `/` is a tmpfs, so an unpreserved incomplete directory would download
      # into RAM and lose half-finished jobs on the reboot ../auto-upgrade.nix
      # may take overnight. Deliberately *not* staged in ./backup.nix: with the
      # config generated from this file, the rest is a re-downloadable queue.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = stateDir;
          user = "sabnzbd";
          group = "sabnzbd";
          mode = "0700";
        }
      ];
    };
}
