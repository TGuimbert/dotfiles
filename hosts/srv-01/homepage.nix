{ config, ... }:
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
      allowedHosts = "localhost:8082,127.0.0.1:8082,homepage.home.guimbert.fr";
      environmentFile = config.sops.secrets.homepageEnvironments.path;
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
                href = "https://homeassistant.home.guimbert.fr/";
                siteMonitor = "https://homeassistant.home.guimbert.fr/";
                description = "Home automation";
                proxmoxNode = "proxmox1";
                proxmoxVMID = 100;
                widget = {
                  type = "homeassistant";
                  url = "https://homeassistant.home.guimbert.fr";
                  key = "{{HOMEPAGE_VAR_HOMEASSISTANT_TOKEN}}";
                };
              };
            }
            {
              Immich = {
                icon = "immich.png";
                href = "https://immich.home.guimbert.fr/";
                siteMonitor = "https://immich.home.guimbert.fr/";
                description = "Photo and video management";
                widget = {
                  type = "immich";
                  url = "https://immich.home.guimbert.fr/";
                  key = "{{HOMEPAGE_VAR_IMMICH_TOKEN}}";
                  version = 2;
                };
              };
            }
            {
              Klipper = {
                icon = "klipper.png";
                href = "http://klipper.home.guimbert.fr";
                siteMonitor = "http://klipper.home.guimbert.fr";
                description = "3D printer management";
                widget = {
                  type = "moonraker";
                  url = "http://klipper.home.guimbert.fr";
                };
              };
            }
            {
              Authelia = {
                icon = "authelia.png";
                href = "https://auth.home.guimbert.fr";
                siteMonitor = "https://auth.home.guimbert.fr";
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
                href = "https://truenas.home.guimbert.fr/";
                siteMonitor = "https://truenas.home.guimbert.fr/";
                description = "Network Attached Storage";
                widget = {
                  type = "truenas";
                  url = "https://truenas.home.guimbert.fr";
                  version = 2;
                  key = "{{HOMEPAGE_VAR_TRUENAS_TOKEN}}";
                  enablePools = true;
                };
              };
            }
            {
              OpenWRT = {
                icon = "openwrt.png";
                href = "https://openwrt.home.guimbert.fr/";
                siteMonitor = "https://openwrt.home.guimbert.fr/";
                description = "Router, DHCP and DNS server and Firewall";
                widget = {
                  type = "openwrt";
                  url = "https://openwrt.home.guimbert.fr";
                  username = "homepage";
                  password = "{{HOMEPAGE_VAR_OPENWRT_PASSWORD}}";
                };
              };
            }
            {
              Traefik = {
                icon = "traefik.png";
                href = "https://traefik.home.guimbert.fr/";
                siteMonitor = "https://traefik.home.guimbert.fr/";
                description = "Reverse proxy";
                widget = {
                  type = "traefik";
                  url = "https://traefik.home.guimbert.fr";
                  headers.Proxy-Authorization = "{{HOMEPAGE_VAR_AUTHELIA_HEADER}}";
                };
              };
            }
            {
              Lldap = {
                icon = "lldap.png";
                href = "https://ldap.home.guimbert.fr";
                siteMonitor = "https://ldap.home.guimbert.fr";
                description = "LDAP server";
              };
            }
            {
              Zoraxy = {
                icon = "zoraxy.png";
                href = "https://zoraxy.home.guimbert.fr";
                siteMonitor = "https://zoraxy.home.guimbert.fr";
                description = "Secondary reverse proxy";
              };
            }
            {
              Garage = {
                icon = "garage.png";
                href = "https://garage-ui.home.guimbert.fr";
                siteMonitor = "https://garage-ui.home.guimbert.fr";
                description = "S3 Object Storage";
              };
            }
            {
              Proxmox1 = {
                icon = "proxmox.png";
                href = "https://proxmox1.home.guimbert.fr:8006/";
                siteMonitor = "https://proxmox1.home.guimbert.fr:8006/";
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
                href = "https://proxmox2.home.guimbert.fr:8006/";
                siteMonitor = "https://proxmox1.home.guimbert.fr:8006/";
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
    traefik.dynamicConfigOptions = {
      http = {
        routers.homepage = {
          rule = "Host(`homepage.home.guimbert.fr`)";
          entrypoints = [ "websecure" ];
          middlewares = [ "authelia" ];
          service = "homepage";
        };
        services.homepage.loadBalancer.servers = [
          { url = "http://localhost:${toString config.services.homepage-dashboard.listenPort}"; }
        ];
      };
    };
  };
}
