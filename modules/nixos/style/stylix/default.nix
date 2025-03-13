{ pkgs, config, ... }:
{
  stylix = {
    enable = true;
    image = pkgs.fetchurl {
      url = "https://gruvbox-wallpapers.pages.dev/wallpapers/irl/stairs.jpg";
      sha256 = "xNL1L/5BguNqapoaEqNKj8sNPsbQxOltsikYjVrBons=";
    };
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";

    cursor = {
      package = pkgs.afterglow-cursors-recolored;
      name = "Afterglow-Recolored-Gruvbox-White";
    };

    fonts = {
      sansSerif = {
        package = pkgs.lato;
        name = "Lato";
      };
      serif = config.stylix.fonts.sansSerif;
      monospace = {
        package = pkgs.nerdfonts.override { fonts = [ "IosevkaTerm" ]; };
        name = "IosevkaTerm Nerd Font";
      };
    };
  };
  boot = {
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
}
