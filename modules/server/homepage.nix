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
          proxmox = {
            proxmox1 = {
              url = "{{HOMEPAGE_VAR_PROXMOX_URL}}";
              token = "{{HOMEPAGE_VAR_PROXMOX_TOKEN}}";
              secret = "{{HOMEPAGE_VAR_PROXMOX_SECRET}}";
            };
            proxmox2 = {
              url = "{{HOMEPAGE_VAR_PROXMOX_URL}}";
              token = "{{HOMEPAGE_VAR_PROXMOX_TOKEN}}";
              secret = "{{HOMEPAGE_VAR_PROXMOX_SECRET}}";
            };
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
                    proxmoxNode = "proxmox1";
                    proxmoxVMID = 100;
                    widget = {
                      type = "homeassistant";
                      url = "https://homeassistant.${constants.domain}";
                      key = "{{HOMEPAGE_VAR_HOMEASSISTANT_TOKEN}}";
                    };
                  };
                }
                {
                  Immich = {
                    icon = "immich.png";
                    href = "https://immich.${constants.domain}/";
                    siteMonitor = "https://immich.${constants.domain}/";
                    description = "Photo and video management";
                    widget = {
                      type = "immich";
                      url = "https://immich.${constants.domain}/";
                      key = "{{HOMEPAGE_VAR_IMMICH_TOKEN}}";
                      version = 2;
                    };
                  };
                }
                {
                  Klipper = {
                    icon = "klipper.png";
                    href = "http://klipper.${constants.domain}";
                    siteMonitor = "http://klipper.${constants.domain}";
                    description = "3D printer management";
                    widget = {
                      type = "moonraker";
                      url = "http://klipper.${constants.domain}";
                    };
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
                    widget = {
                      type = "truenas";
                      url = "https://truenas.${constants.domain}";
                      version = 2;
                      key = "{{HOMEPAGE_VAR_TRUENAS_TOKEN}}";
                      enablePools = true;
                    };
                  };
                }
                {
                  OpenWRT = {
                    icon = "openwrt.png";
                    href = "https://openwrt.${constants.domain}/";
                    siteMonitor = "https://openwrt.${constants.domain}/";
                    description = "Router, DHCP and DNS server and Firewall";
                    widget = {
                      type = "openwrt";
                      url = "https://openwrt.${constants.domain}";
                      username = "homepage";
                      password = "{{HOMEPAGE_VAR_OPENWRT_PASSWORD}}";
                    };
                  };
                }
                {
                  Traefik = {
                    icon = "traefik.png";
                    href = "https://traefik.${constants.domain}/";
                    siteMonitor = "https://traefik.${constants.domain}/";
                    description = "Reverse proxy";
                    widget = {
                      type = "traefik";
                      url = "https://traefik.${constants.domain}";
                      headers.Proxy-Authorization = "{{HOMEPAGE_VAR_AUTHELIA_HEADER}}";
                    };
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
                  Zoraxy = {
                    icon = "zoraxy.png";
                    href = "https://zoraxy.${constants.domain}";
                    siteMonitor = "https://zoraxy.${constants.domain}";
                    description = "Secondary reverse proxy";
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
                {
                  Proxmox1 = {
                    icon = "proxmox.png";
                    href = "https://proxmox1.${constants.domain}:8006/";
                    siteMonitor = "https://proxmox1.${constants.domain}:8006/";
                    description = "First PVE node";
                    widget = {
                      type = "proxmox";
                      url = "{{HOMEPAGE_VAR_PROXMOX_URL}}";
                      username = "{{HOMEPAGE_VAR_PROXMOX_TOKEN}}";
                      password = "{{HOMEPAGE_VAR_PROXMOX_SECRET}}";
                      node = "proxmox1";
                    };
                  };
                }
                {
                  Proxmox2 = {
                    icon = "proxmox.png";
                    href = "https://proxmox2.${constants.domain}:8006/";
                    siteMonitor = "https://proxmox1.${constants.domain}:8006/";
                    description = "Second PVE node";
                    widget = {
                      type = "proxmox";
                      url = "{{HOMEPAGE_VAR_PROXMOX_URL}}";
                      username = "{{HOMEPAGE_VAR_PROXMOX_TOKEN}}";
                      password = "{{HOMEPAGE_VAR_PROXMOX_SECRET}}";
                      node = "proxmox2";
                    };
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
