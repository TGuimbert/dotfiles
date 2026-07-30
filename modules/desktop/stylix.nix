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

  homeManager.modules.gui =
    { config, ... }:
    {
      stylix = {
        enable = true;
        targets = {
          starship.enable = true;
          firefox.profileNames = [ "default" ];
          qt.enable = false;
          # These two write their themes whether or not the desktop is installed,
          # unlike most targets. The GNOME one also carried the interface
          # gsettings re-declared below, which GTK4 apps read outside GNOME.
          gnome.enable = false;
          kde.enable = false;
        };
      };

      # What stylix.targets.gnome used to set, minus the shell theming. Nautilus
      # and the GTK file dialogs pick their dark variant from color-scheme; the
      # font keys are read by GTK apps that don't parse settings.ini (emacs-pgtk
      # and friends). Cursor keys are not here: home.pointerCursor writes those.
      dconf.settings."org/gnome/desktop/interface" =
        let
          fontSize = toString config.stylix.fonts.sizes.applications;
        in
        {
          color-scheme = if config.stylix.polarity == "dark" then "prefer-dark" else "default";
          font-name = "${config.stylix.fonts.sansSerif.name} ${fontSize}";
          document-font-name = "${config.stylix.fonts.serif.name} ${
            toString (config.stylix.fonts.sizes.applications - 1)
          }";
          monospace-font-name = "${config.stylix.fonts.monospace.name} ${fontSize}";
        };
    };
}
