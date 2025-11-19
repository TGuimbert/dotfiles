{ pkgs, lib, ... }:
{
  # Nix settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://cache.nixos.org/"
      "https://tguimbert.cachix.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "tguimbert.cachix.org-1:PDa22nLjEwxsABhCz09ONTfYAP3DJOAJRszoy007ojs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    auto-optimise-store = true;
  };
  programs = {
    nh = {
      enable = true;
      flake = "/home/tguimbert/.dotfiles";
      clean = {
        enable = true;
        dates = "weekly";
        extraArgs = "--keep 5 --keep-since 3d";
      };
    };
    nix-ld.enable = true;
  };

  # Boot
  boot = {
    loader = {
      systemd-boot.enable = false;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
    bootspec.enable = true;
    tmp.useTmpfs = true;
    initrd.systemd.enable = true;
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    plymouth.enable = true;
    # Enable "Silent Boot"
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    # Hide the OS choice for bootloaders.
    # It's still possible to open the bootloader list by pressing any key
    # It will just not appear on screen unless a key is pressed
    loader.timeout = 0;
  };

  # Locale
  time.timeZone = "Europe/Paris";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "fr_FR.UTF-8";
      LC_IDENTIFICATION = "fr_FR.UTF-8";
      LC_MEASUREMENT = "fr_FR.UTF-8";
      LC_MONETARY = "fr_FR.UTF-8";
      LC_NAME = "fr_FR.UTF-8";
      LC_NUMERIC = "fr_FR.UTF-8";
      LC_PAPER = "fr_FR.UTF-8";
      LC_TELEPHONE = "fr_FR.UTF-8";
      LC_TIME = "fr_FR.UTF-8";
    };
  };

  # Keyboard
  services.xserver = {
    xkb = {
      layout = "us";
      variant = "intl";
    };
  };
  console.keyMap = "us";

  # User
  users = {
    mutableUsers = false;
    users.tguimbert = {
      name = "tguimbert";
      description = "Thibault Guimbert";
      isNormalUser = true;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      uid = 1000;
      shell = pkgs.bashInteractive;
      hashedPasswordFile = "/persistent/tguimbert-password";
    };
  };

  security.sudo.extraConfig = "Defaults lecture=\"never\"";

  # Networking
  networking = {
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  # Audio
  security.rtkit.enable = true;
  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  # Services
  services = {
    openssh.enable = true;
    printing.enable = true;
    fwupd.enable = true;
    pcscd.enable = true;
    btrfs.autoScrub.enable = true;
  };

  # Secrets
  sops = {
    defaultSopsFile = ../../secrets/common.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.smb-secrets = { };
  };

  # Shares
  fileSystems."/mnt/share" = {
    device = "//192.168.1.100/Home";
    fsType = "cifs";
    options =
      let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      [
        "${automount_opts},credentials=/run/secrets/smb-secrets,uid=1000,gid=100"
      ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
    ];
  };

  environment.systemPackages = with pkgs; [
    sbctl
    cifs-utils
    qemu
  ];

}
