{ ... }:
{
  nixos.modules.homepage =
    {
      config,
      constants,
      mkAutheliaRouter,
      ...
    }:
    {
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
          services = [
            {
              Services = [
                {
                  HomeAssistant = {
                    icon = "home-assistant.png";
                    href = "https://homeassistant.${constants.domain}/";
                    siteMonitor = "https://homeassistant.${constants.domain}/";
                    description = "Home automation";
                  };
                }
                {
                  Immich = {
                    icon = "immich.png";
                    href = "https://immich.${constants.domain}/";
                    siteMonitor = "https://immich.${constants.domain}/";
                    description = "Photo and video management";
                  };
                }
                {
                  Klipper = {
                    icon = "klipper.png";
                    href = "http://klipper.${constants.domain}";
                    siteMonitor = "http://klipper.${constants.domain}";
                    description = "3D printer management";
                  };
                }
                {
                  Authelia = {
                    icon = "authelia.png";
                    href = "https://auth.${constants.domain}";
                    siteMonitor = "https://auth.${constants.domain}";
                    description = "Authentication management";
                  };
                }
              ];
            }
            {
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
                  "Traefik srv-01" = {
                    icon = "traefik.png";
                    href = "https://traefik.${constants.domain}/dashboard/";
                    siteMonitor = "https://traefik.${constants.domain}/dashboard/";
                    description = "Reverse proxy";
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
                  Lldap = {
                    icon = "lldap.png";
                    href = "https://ldap.${constants.domain}";
                    siteMonitor = "https://ldap.${constants.domain}";
                    description = "LDAP server";
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
            }
          ];
        };
        traefik.dynamicConfigOptions.http = mkAutheliaRouter {
          name = "homepage";
          port = config.services.homepage-dashboard.listenPort;
        };
      };
    };
}
