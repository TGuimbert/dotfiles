{ ... }:
{
  # Sonarr, Radarr and Prowlarr in one aspect: they are deployed together, share
  # the library mount, the sops shape and the Authelia routers, and differ only
  # in the table below. The downloader they hand releases to is its own aspect,
  # ./sabnzbd.nix — it shares none of that shape.
  nixos.modules.servarr =
    {
      config,
      constants,
      lib,
      mediaLibrary,
      mkAutheliaRouter,
      ...
    }:
    let
      apps = {
        sonarr = {
          title = "Sonarr";
          description = "TV series library";
          writesLibrary = true;
        };
        radarr = {
          title = "Radarr";
          description = "Movie library";
          writesLibrary = true;
        };
        prowlarr = {
          title = "Prowlarr";
          description = "Indexer manager";
          writesLibrary = false;
        };
      };
      names = lib.attrNames apps;
      writers = lib.attrNames (lib.filterAttrs (_: app: app.writesLibrary) apps);
    in
    {
      users = {
        users =
          lib.genAttrs writers (_: {
            # So an import can write to the NFS mount. Their uids are static in
            # nixpkgs' own ids.nix (274/275), so unlike jellyfin and prowlarr
            # there is nothing here to pin.
            extraGroups = [ mediaLibrary.group ];
          })
          // {
            prowlarr = {
              isSystemUser = true;
              group = "prowlarr";
              # Chosen, like jellyfin's — upstream runs prowlarr under
              # DynamicUser, so nixpkgs allocates it no static id.
              uid = 353;
            };
          };
        groups.prowlarr.gid = 353;
      };

      homepageTiles.Services = lib.mapAttrsToList (name: app: {
        ${app.title} = {
          icon = "${name}.png";
          href = "https://${name}.${constants.domain}";
          siteMonitor = "https://${name}.${constants.domain}";
          inherit (app) description;
        };
      }) apps;

      # The key is the secret; the `<APP>__AUTH__APIKEY=…` line these modules
      # want is *rendered* from it. Storing the env line directly would mean a
      # second copy of every key as soon as something needs one bare, which
      # ./recyclarr.nix does — and two copies of a credential drift. One file per
      # app rather than a shared blob, so none of them can read another's. From
      # sops so the keys survive a restore instead of being regenerated behind
      # Prowlarr's back.
      sops = {
        secrets = lib.mapAttrs' (name: _: lib.nameValuePair "${name}ApiKey" { owner = name; }) apps;
        templates = lib.mapAttrs' (
          name: _:
          lib.nameValuePair "${name}Environment" {
            owner = name;
            content = "${lib.toUpper name}__AUTH__APIKEY=${config.sops.placeholder."${name}ApiKey"}";
          }
        ) apps;
      };

      services =
        lib.genAttrs names (name: {
          enable = true;
          # Flat, and the same path preservation bind-mounts. Sonarr and radarr
          # default to burying their config two levels down (.config/NzbDrone,
          # .config/Radarr), where their tmpfiles rules create the intermediate
          # directory as root inside a service-owned parent — which systemd then
          # refuses to canonicalize ("unsafe path transition") on every later
          # run. prowlarr's default is already this, so it changes only the two.
          dataDir = "/var/lib/${name}";
          settings = {
            # Traefik is the only way in: bound to loopback, and `openFirewall`
            # left at its default false.
            server.bindaddress = "127.0.0.1";
            # Delegated to the Authelia middleware in front, which is the
            # stronger of the two anyway. `"Forms"` is a trap here: these apps
            # only offer the screen that *creates* their first user while no
            # method is configured, so setting one before first run leaves a
            # login page and an empty user table, with no way in.
            auth = {
              method = "External";
              required = "Enabled";
            };
          };
          environmentFiles = [ config.sops.templates."${name}Environment".path ];
        })
        // {
          traefik.dynamicConfigOptions.http = lib.mkMerge (
            map (
              name:
              mkAutheliaRouter {
                inherit name;
                inherit (config.services.${name}.settings.server) port;
              }
            ) names
          );
        };

      systemd.services =
        lib.genAttrs writers (_: {
          unitConfig.RequiresMountsFor = [ mediaLibrary.dir ];
          # mkForce because the modules set 0022, and 0002 is not cosmetic here: a
          # POSIX default ACL is capped by the mask the creation mode implies, so
          # a directory created under 0022 lands group `r-x` on the NAS and the
          # next writer — a manual copy over SMB — cannot write into it.
          serviceConfig.UMask = lib.mkForce "0002";
        })
        // {
          prowlarr.serviceConfig = {
            # Same reason as ./lldap.nix: DynamicUser allocates a uid per boot,
            # and the next boot cannot read the state the last one wrote. Turning
            # it off also moves the state out of /var/lib/private/prowlarr, which
            # is where the ExecStart's `-data` bind-mount would otherwise point.
            DynamicUser = lib.mkForce false;
            User = "prowlarr";
            Group = "prowlarr";
            # The only one of the three whose state directory systemd still
            # creates, so the only one that would fight the mode below.
            StateDirectoryMode = "0700";
          };
        };

      # Ownership spelled out for the same reason as ./traefik.nix.
      preservation.preserveAt."/persistent".directories = map (name: {
        directory = config.services.${name}.dataDir;
        user = name;
        group = name;
        mode = "0700";
      }) names;
    };
}
