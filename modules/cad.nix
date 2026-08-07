{ ... }:
let
  # OpenJDK 21 resolves Swing's *system* look and feel to GTKLookAndFeel wherever
  # libgtk-3 loads — `sun.desktop` being unset is not enough to get Metal. Java's GTK
  # backend predates CSS themes, so against adw-gtk3 plus noctalia's gtk.css
  # (./desktop/appearance.nix) it draws highlighted text in the text colour. GTK_THEME=
  # does not help: noctalia's colours are a *user* stylesheet layered over whatever
  # theme is named. Naming Metal wins because SweetHome3D.initLookAndFeel() passes the
  # system look and feel as the *default* of getProperty("swing.defaultlaf").
  javaOptions = [
    "-Dswing.defaultlaf=javax.swing.plaf.metal.MetalLookAndFeel"
    # Metal's defaults are sized for 96 DPI. SansSerif is a *logical* family — the JDK
    # resolves it through fontconfig, already pointed at Inter by ./desktop/appearance.nix.
    "-Dswing.plaf.metal.controlFont=SansSerif-13"
    "-Dswing.plaf.metal.systemFont=SansSerif-13"
    "-Dswing.plaf.metal.userFont=SansSerif-13"
    "-Dswing.plaf.metal.smallFont=SansSerif-11"
    # niri runs no XSETTINGS manager, so Java finds no antialiasing hint and uses none.
    "-Dawt.useSystemAAFontSettings=lcd"
    "-Dswing.aatext=true"
  ];
in
{
  homeManager.modules.gui =
    { lib, pkgs, ... }:
    {
      home.packages = with pkgs; [
        freecad
        orca-slicer
        (sweethome3d.application.overrideAttrs (old: {
          # NOT --add-flags: the wrapper underneath ends in `-jar …`, so appended flags
          # reach SweetHome3D's main() as filenames, never the JVM. JDK_JAVA_OPTIONS is
          # prepended by the JDK 9+ launcher.
          #
          # _JAVA_AWT_WM_NONREPARENTING is niri's documented Java workaround, and the
          # first rung against Swing popups dismissing themselves under xwayland-satellite
          # (niri#2752, open): AWT maps them override-redirect and XGrabPointers, XWayland
          # cannot honour the grab, and MouseGrabber closes them on the focus loss. Next
          # rungs are -Dsun.awt.disablegrab=true here, then an open-floating window rule.
          postFixup = (old.postFixup or "") + ''
            wrapProgram $out/bin/sweethome3d \
              --set _JAVA_AWT_WM_NONREPARENTING 1 \
              --set JDK_JAVA_OPTIONS "${lib.concatStringsSep " " javaOptions}"
          '';
        }))
        calibre
      ];

    };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.directories = [
    ".config/OrcaSlicer"
    ".config/FreeCAD"
    ".cache/FreeCAD"
    ".cache/orca-slicer"
    ".local/share/FreeCAD"
    # Sweet Home 3D splits its state: the Java Preferences store holds units, language
    # and recent files, ~/.eteks the imported furniture, textures and plug-ins. It is the
    # only Java GUI app here, so .java is preserved whole rather than a deep .userPrefs path.
    ".java"
    ".eteks"
  ];
}
