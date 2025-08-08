{ lib
, pkgs
, config
, ...
}:
let
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILztL16pShpN/loc4tkq1V6zKmDNu/WWtMEJk4zadHHO tguimbert@work"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIFH1m31u/W8216NNkdrbvlJf0D3JRla16XD8clMeGDRyAAAABHNzaDo="
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIItgAyaI4GxuTh2LU+Z7cWDb1HIEfVMWxJ5mRwDiGmbOAAAABHNzaDo="
  ];
in
{
  boot.initrd.availableKernelModules = [ "usbhid" ];
  boot.kernelPackages = pkgs.linuxPackages;

  networking = {
    hostName = "klipper";
    networkmanager = {
      enable = true;
      ensureProfiles = {
        environmentFiles = [ config.sops.secrets."wireless.env".path ];
        profiles = {
          home-wifi = {
            connection = {
              id = "home-wifi";
              type = "wifi";
            };
            wifi.ssid = "$HOME_WIFI_SSID";
            wifi-security = {
              auth-alg = "open";
              key-mgmt = "wpa-psk";
              psk = "$HOME_WIFI_PASSWORD";
            };
          };
        };
      };
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [
        80
        config.services.moonraker.port
        1984
      ];
    };
  };

  time.timeZone = "Europe/Paris";

  users = {
    mutableUsers = false;
    users = {
      tguimbert = {
        isNormalUser = true;
        hashedPasswordFile = config.sops.secrets.tguimbert-password.path;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = authorizedKeys;
      };
      root.openssh.authorizedKeys.keys = authorizedKeys;
      klipper = {
        isSystemUser = true;
        group = "klipper";
      };
    };
    groups.klipper = { };
  };

  environment.systemPackages = with pkgs; [
    helix
    bottom
  ];

  services = {
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      extraConfig = ''
        AllowTcpForwarding yes
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
        AuthenticationMethods publickey
      '';
    };
    klipper = {
      enable = true;
      configFile = ./printer.cfg;
      firmwares.mcu = {
        enable = true;
        enableKlipperFlash = true;
        configFile = ./mcu.cfg;
        serial = "/dev/serial/by-id/usb-Klipper_stm32g0b1xx_4F00350002504B5735313920-if00";
      };
    };
    moonraker = {
      enable = true;
      group = "klipper";
      address = "0.0.0.0";
      settings = {
        file_manager = {
          enable_object_processing = true;
        };
        data_store = {
          temperature_store_size = 600;
          gcode_store_size = 1000;
        };
        authorization = {
          cors_domains = [
            "*.local"
            "*.lan"
            "*://localhost"
            "*://klipper"
          ];
          trusted_clients = [
            "10.0.0.0/8"
            "127.0.0.0/8"
            "169.254.0.0/16"
            "172.16.0.0/12"
            "192.168.0.0/16"
            "FE80::/10"
            "::1/128"
          ];
        };
        history = { };
        update_manager = {
          enable_auto_refresh = false;
          enable_system_updates = [ false ];
        };
        announcements = {
          subscriptions = [ "fluidd" ];
        };
      };
      allowSystemControl = true;
    };
    fluidd.enable = true;
    go2rtc = {
      enable = true;
      settings = {
        streams = {
          usbcam = "ffmpeg:device?video=0&resolution=1280x720#video=h264";
        };
        api = {
          origin = "*";
        };
      };
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  sops = {
    defaultSopsFile = ./secrets/klipper.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    secrets = {
      tguimbert-password.neededForUsers = true;
      "wireless.env" = { };
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "25.05";
}
