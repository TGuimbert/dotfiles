# The desktop's fixed appearance: fonts, cursor, wallpaper and the GTK base theme
# — everything noctalia does *not* own. noctalia is the authority for colors in a
# running session (./noctalia.nix renders palettes for foot, helix, zellij, bat,
# starship, GTK, Firefox, …); this file provides what has no live-templating story,
# plus the constants those files share.
{ ... }:
let
  # Read by ./greeter.nix (NixOS) and ./noctalia.nix + ../terminal.nix (home-manager),
  # so it is injected as a module arg on both classes below — a nixos aspect cannot
  # import a home-manager one. Same shape as ../constants.nix. Each aspect binds the
  # result locally rather than reading back its own `_module.args`, which would be a
  # self-reference.
  mkAppearance = pkgs: {
    # One UI sans for the whole desktop. Inter is drawn for screen UI — it stays
    # legible at bar sizes where Lato went soft. Also serves as the serif: no
    # serifs anywhere. One size, used by GTK, the dconf font keys and foot.
    font = {
      package = pkgs.inter;
      name = "Inter";
      size = 12;
    };

    monospace = {
      package = pkgs.nerd-fonts.iosevka-term;
      name = "IosevkaTerm Nerd Font";
    };

    cursor = {
      package = pkgs.afterglow-cursors-recolored;
      name = "Afterglow-Recolored-Gruvbox-White";
      size = 24;
    };

    # Seeds noctalia's wallpaper folder and backs the greeter, so login screen and
    # session open on the same image.
    wallpaper = pkgs.fetchurl {
      url = "https://gruvbox-wallpapers.pages.dev/wallpapers/photography/stairs.jpg";
      sha256 = "xNL1L/5BguNqapoaEqNKj8sNPsbQxOltsikYjVrBons=";
    };
  };
in
{
  nixos.modules.desktop =
    { pkgs, ... }:
    let
      appearance = mkAppearance pkgs;
    in
    {
      _module.args.appearance = appearance;

      fonts = {
        packages = [
          appearance.font.package
          appearance.monospace.package
        ];

        # Emoji comes from fonts.enableDefaultPackages (set in ./niri.nix), which
        # also supplies the dejavu/liberation/noto-cjk fallbacks.
        fontconfig.defaultFonts = {
          sansSerif = [ appearance.font.name ];
          serif = [ appearance.font.name ];
          monospace = [ appearance.monospace.name ];
          emoji = [ "Noto Color Emoji" ];
        };
      };

      # Not optional: it installs the dconf GSettings backend (GIO_EXTRA_MODULES),
      # its dbus service and the `dconf` binary. Without it every gsettings write
      # lands in the memory backend and is lost — including the ones noctalia's
      # gtk/apply.sh makes on each day/night flip (`color-scheme`, `gtk-theme`),
      # which is what actually switches GTK apps. home-manager's dconf.settings
      # and home.pointerCursor.gtk go through the same path.
      programs.dconf.enable = true;

      # GSettings schemas for a session that is not GNOME. GTK reads its font,
      # cursor and color-scheme from org.gnome.desktop.interface, but nixpkgs
      # installs schemas to share/gsettings-schemas/<pkg>/glib-2.0/schemas — one
      # level below where GLib looks — so each package's dir has to be named on
      # XDG_DATA_DIRS. GNOME's session did that for us.
      #
      # Without it GTK finds no schemas at all and Firefox draws its whole chrome
      # with no text (menus collapse to a sliver, sizing to empty labels) while
      # page content renders fine. Same root cause as the FreeCAD file-dialog
      # crash worked around in ../nixpkgs.nix (nixpkgs#467783).
      environment.sessionVariables.XDG_DATA_DIRS = [
        "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
        "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
        "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}"
      ];
    };

  homeManager.modules.gui =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      appearance = mkAppearance pkgs;
      fontSize = toString appearance.font.size;
      uiFont = "${appearance.font.name} ${fontSize}";
    in
    {
      _module.args.appearance = appearance;

      gtk = {
        enable = true;
        # Only the package has to exist on a themes path: noctalia's gtk/apply.sh
        # flips gtk-theme between adw-gtk3 and adw-gtk3-dark at runtime, so the
        # name here is just the variant the session starts in.
        theme = {
          package = pkgs.adw-gtk3;
          name = "adw-gtk3";
        };
        gtk4.theme = config.gtk.theme;
        font = { inherit (appearance.font) package name size; };
      };

      # noctalia renders the colors to gtk-{3,4}.0/noctalia.css; this is the file
      # that pulls them in. @import has to come before every other rule or GTK's
      # parser drops it, so gtk.css holds nothing else. apply.sh checks for the
      # import and, finding it, leaves this read-only symlink alone.
      xdg.configFile = lib.genAttrs [ "gtk-3.0/gtk.css" "gtk-4.0/gtk.css" ] (_: {
        text = ''
          @import url("noctalia.css");
        '';
      });

      home.pointerCursor = {
        inherit (appearance.cursor) package name size;
        gtk.enable = true;
        x11.enable = true;
      };

      # GTK4 apps and anything that doesn't parse settings.ini (emacs-pgtk and
      # friends) read these instead. No cursor or gtk-theme keys — home.pointerCursor
      # and gtk.theme above write those. color-scheme is only the value the session
      # boots with; noctalia's apply.sh overwrites it on every mode flip, the same
      # way ./noctalia.nix seeds foot's theme file ahead of the first render.
      dconf.settings."org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        font-name = uiFont;
        document-font-name = uiFont;
        monospace-font-name = "${appearance.monospace.name} ${fontSize}";
      };
    };
}
