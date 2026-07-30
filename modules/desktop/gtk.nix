# GSettings schemas for a session that is not GNOME. GTK reads its font, cursor
# and color-scheme from org.gnome.desktop.interface, but nixpkgs installs schemas
# to share/gsettings-schemas/<pkg>/glib-2.0/schemas — one level below where GLib
# looks — so each package's dir has to be named on XDG_DATA_DIRS. GNOME's session
# did that for us.
#
# Without it GTK finds no schemas at all and Firefox draws its whole chrome with
# no text (menus collapse to a sliver, sizing to empty labels) while page content
# renders fine. Same root cause as the FreeCAD file-dialog crash worked around in
# modules/nixpkgs.nix (nixpkgs#467783).
{ ... }:
{
  nixos.modules.desktop =
    { pkgs, ... }:
    {
      environment.sessionVariables.XDG_DATA_DIRS = [
        "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
        "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
        "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}"
      ];
    };
}
