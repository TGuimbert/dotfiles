{ lib, ... }:
let
  gv = lib.home-manager.hm.gvariant;
in
{
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      sources = gv.mkArray (gv.type.tupleOf [ gv.type.string gv.type.string ]) [ (gv.mkTuple [ "xkb" "fr+bepo" ]) (gv.mkTuple [ "xkb" "fr+oss" ]) ];
    };
    "org/gnome/desktop/peripherals/keyboard" = {
      numlock-state = true;
    };
    "org/gnome/desktop/interface" = {
      color-scheme = gv.mkString "prefer-dark";
    };
    "org/gnome/shell" = {
      favorite-apps = gv.mkArray gv.type.string [
        "firefox.desktop"
        "org.wezfurlong.wezterm.desktop"
        "spotify.desktop"
        "org.gnome.Nautilus.desktop"
      ];
    };
    "org/gnome/desktop/screensave" = {
      color-shading-type = gv.mkString "solid";
      picture-options = gv.mkString "zoom";
      picture-uri = gv.mkString "file:///run/current-system/sw/share/backgrounds/gnome/adwaita-l.webp";
      primary-color = gv.mkString "#3071AE";
      secondary-color = gv.mkString "#000000";
    };
  };
}
