{ lib, ... }:
let
  gv = lib.home-manager.hm.gvariant;
in
{
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      sources =
        gv.mkArray
          (gv.type.tupleOf [
            gv.type.string
            gv.type.string
          ])
          [
            (gv.mkTuple [
              "xkb"
              "us+intl"
            ])
            (gv.mkTuple [
              "xkb"
              "fr+oss"
            ])
          ];
    };
    "org/gnome/shell" = {
      favorite-apps = gv.mkArray gv.type.string [
        "firefox.desktop"
        "footclient.desktop"
        "spotify.desktop"
        "org.gnome.Nautilus.desktop"
      ];
    };
  };
}
