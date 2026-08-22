{ ... }:
{
  nixos.modules.homepage =
    {
      config,
      constants,
      lib,
      mkAutheliaRouter,
      ...
    }:
    let
      # Group order is a property of the dashboard, so it stays here rather than
      # being inferred from whatever order the modules happened to merge in.
      groupOrder = [
        "Services"
        "Admin"
      ];

      # Merge order within a group follows module evaluation rather than intent,
      # so sort by tile name for something stable instead.
      sortTiles = lib.sortOn (tile: lib.head (lib.attrNames tile));
    in
    {
      # Collector, so a service's tile lives beside the rest of that service's
      # config rather than in a central list that drifts — calibre-web had no tile
      # at all until this moved. Keyed by group because
      # `services.homepage-dashboard.services` is a *list* of groups and list
      # definitions concatenate: two files contributing to "Admin" directly would
      # render two groups called Admin. Attrsets merge by key instead. An aspect
      # setting this depends on `homepage` being imported.
      options.homepageTiles = lib.mkOption {
        type = with lib.types; attrsOf (listOf attrs);
        default = { };
        description = "Homepage tiles, keyed by the dashboard group they belong to.";
      };

      config = {
        assertions = [
          {
            assertion = lib.all (group: lib.elem group groupOrder) (lib.attrNames config.homepageTiles);
            message = ''
              homepageTiles declares a group outside `groupOrder` in
              modules/server/homepage.nix, so its tiles would be dropped without
              a word. Groups: ${lib.concatStringsSep ", " (lib.attrNames config.homepageTiles)}
            '';
          }
        ];

        users.groups.homepage-secrets = { };
        systemd.services.homepage-dashboard = {
          environment = {
            UV_THREADPOOL_SIZE = "64";
            NODE_OPTIONS = "--dns-result-order=ipv4first";
          };
          serviceConfig.SupplementaryGroups = "homepage-secrets";
        };
        sops.secrets.homepageEnvironments = {
          group = "homepage-secrets";
          mode = "0440";
        };

        # Everything off this host, which has no aspect here to live in. The
        # rest is declared by the service it belongs to.
        homepageTiles = {
          Services = [
            {
              Immich = {
                icon = "immich.png";
                href = "https://immich.${constants.domain}/";
                siteMonitor = "https://immich.${constants.domain}/";
                description = "Photo and video management";
              };
            }
          ];
          Admin = [
            {
              Truenas = {
                icon = "truenas.png";
                href = "https://truenas.${constants.domain}/";
                siteMonitor = "https://truenas.${constants.domain}/";
                description = "Network Attached Storage";
              };
            }
            {
              OpenWRT = {
                icon = "openwrt.png";
                href = "https://openwrt.${constants.domain}/";
                siteMonitor = "https://openwrt.${constants.domain}/";
                description = "Router, DHCP and DNS server and Firewall";
              };
            }
            {
              "Traefik NAS" = {
                icon = "traefik.png";
                href = "https://traefik-nas.${constants.domain}/dashboard/";
                siteMonitor = "https://traefik-nas.${constants.domain}/dashboard/";
                description = "Reverse proxy";
              };
            }
            {
              Garage = {
                icon = "garage.png";
                href = "https://garage-ui.${constants.domain}";
                siteMonitor = "https://garage-ui.${constants.domain}";
                description = "S3 Object Storage";
              };
            }
          ];
        };

        services = {
          homepage-dashboard = {
            enable = true;
            allowedHosts = "localhost:8082,127.0.0.1:8082,homepage.${constants.domain}";
            environmentFiles = [ config.sops.secrets.homepageEnvironments.path ];
            settings = {
              statusStyle = "dot";
            };
            widgets = [
              {
                datetime = {
                  text_size = "xl";
                  locale = "fr";
                  format = {
                    dateStyle = "long";
                    timeStyle = "long";
                  };
                };
              }
              {
                openmeteo = {
                  label = "{{HOMEPAGE_VAR_OPENMETEO_LABEL}}";
                  latitude = "{{HOMEPAGE_VAR_OPENMETEO_LATITUDE}}";
                  longitude = "{{HOMEPAGE_VAR_OPENMETEO_LONGITUDE}}";
                  units = "metric";
                  cache = 5;
                  format.maximumFractionDigits = 1;
                };
              }
            ];
            services = map (group: {
              ${group} = sortTiles (config.homepageTiles.${group} or [ ]);
            }) groupOrder;
          };

          traefik.dynamicConfigOptions.http = mkAutheliaRouter {
            name = "homepage";
            port = config.services.homepage-dashboard.listenPort;
          };
        };
      };
    };
}
