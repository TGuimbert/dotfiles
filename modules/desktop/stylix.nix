{ inputs, ... }:
{
  nixos.modules.desktop =
    { pkgs, ... }:
    {
      imports = [ inputs.stylix.nixosModules.stylix ];

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
    };

  homeManager.modules.gui = {
    stylix = {
      enable = true;
      targets = {
        starship.enable = true;
        firefox.profileNames = [ "default" ];
        qt.platform = "qtct";
        qt.enable = false;
      };
    };
  };
}
