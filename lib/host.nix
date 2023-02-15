{ system, pkgs, home-manager, lib, ... }:
with builtins;
{
  mkHost = { name, userName,
    initrdAvailMods, initrdMods,
    kernelMods, extraModPkgs
  }:
  lib.nixosSystem {
    inherit system;

    modules = [
      {
        imports = [ ../modules/system/griffin.nix ];

        # Bootloader.
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;
        boot.loader.efi.efiSysMountPoint = "/boot/efi";

        # Setup keyfile
        boot.initrd.secrets = {
          "/crypto_keyfile.bin" = null;
        };

        networking.hostName = "${name}";

        networking.networkmanager.enable = true;
        networking.useDHCP = lib.mkDefault true;

        boot.initrd.availableKernelModules = initrdAvailMods;
        boot.initrd.kernelModules = initrdMods;
        boot.kernelModules = kernelMods;
        boot.extraModulePackages = extraModPkgs;

        # Allow unfree packages
        nixpkgs.config.allowUnfree = true;
        # Enable flakes
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
    
        time.timeZone = "Europe/Paris";
        # Select internationalisation properties.
        i18n.defaultLocale = "en_US.UTF-8";
        i18n.extraLocaleSettings = {
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

        # Enable the X11 windowing system.
        services.xserver.enable = true;
        # Enable the GNOME Desktop Environment.
        services.xserver.displayManager.gdm.enable = true;
        services.xserver.desktopManager.gnome.enable = true;

        # Configure keymap in X11
        services.xserver = {
          layout = "fr";
          xkbVariant = "bepo";
        };
        # Configure console keymap
        console.keyMap = "fr";

        # Enable CUPS to print documents.
        services.printing.enable = true;

        # Enable sound with pipewire.
        sound.enable = true;
        hardware.pulseaudio.enable = false;
        security.rtkit.enable = true;
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };

        services.pcscd.enable = true;

    		users.users."${userName}" = {
    			name = userName;
    			isNormalUser = true;
    			isSystemUser = false;
    			extraGroups = [ "networkmanager" "wheel" ];
    			uid = 1000;
    			initialPassword = "password";
    			shell = pkgs.bashInteractive;
    		};

        environment.systemPackages = with pkgs; [
          pinentry-gnome
          wl-clipboard
        ];

        virtualisation.podman = {
          enable = true;
          dockerCompat = true;
          defaultNetwork.settings.dns_enabled = true;
        };

        # This value determines the NixOS release from which the default
        # settings for stateful data, like file locations and database versions
        # on your system were taken. It‘s perfectly fine and recommended to leave
        # this value at the release version of the first install of this system.
        # Before changing this value read the documentation for this option
        # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
        system.stateVersion = "22.11"; # Did you read the comment?
      }
    ];
  };
}