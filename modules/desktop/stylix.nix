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
          # One UI sans for the whole desktop: stylix themes GTK/GNOME with it and
          # noctalia's bar inherits it (modules/niri/noctalia.nix). Inter is drawn for
          # screen UI — it stays legible at bar sizes where Lato went soft. serif
          # mirrors it, as it did with Lato: no serifs anywhere.
          sansSerif = {
            package = pkgs.inter;
            name = "Inter";
          };
          serif = {
            package = pkgs.inter;
            name = "Inter";
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
