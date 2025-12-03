{ pkgs, ... }:
{
  services = {
    xserver.enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  environment = {
    gnome.excludePackages = with pkgs; [ gnome-tour ];
    systemPackages = with pkgs; [ wl-clipboard ];
  };

  stylix = {
    enable = true;
    image = pkgs.fetchurl {
      url = "https://gruvbox-wallpapers.pages.dev/wallpapers/photography/stairs.jpg";
      sha256 = "xNL1L/5BguNqapoaEqNKj8sNPsbQxOltsikYjVrBons=";
    };
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
    cursor = {
      package = pkgs.afterglow-cursors-recolored;
      name = "Afterglow-Recolored-Gruvbox-White";
      size = 24;
    };
    fonts = {
      sansSerif = {
        package = pkgs.lato;
        name = "Lato";
      };
      serif = {
        package = pkgs.lato;
        name = "Lato";
      };
      monospace = {
        package = pkgs.nerd-fonts.iosevka-term;
        name = "IosevkaTerm Nerd Font";
      };
    };
    targets.qt.enable = false;
  };
}
