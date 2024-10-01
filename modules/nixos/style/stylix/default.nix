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
}
