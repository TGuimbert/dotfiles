# Files and removable storage: the file manager plus the daemons GNOME used to
# enable behind it. Nautilus needs udisks2 to see USB media and gvfs for trash,
# network and MTP backends; portal-gnome's file *dialogs* also dispatch to it
# (see the D-Bus wiring in ./niri.nix).
{ ... }:
{
  nixos.modules.desktop =
    { pkgs, ... }:
    {
      services = {
        gvfs.enable = true;
        udisks2.enable = true;
      };

      # "Open in Terminal" in nautilus' context menu.
      programs.nautilus-open-any-terminal = {
        enable = true;
        terminal = "foot";
      };

      environment.systemPackages = with pkgs; [
        nautilus
        # Where GTK apps find their icons; GNOME used to install it.
        adwaita-icon-theme
        # Formatting removable media, in place of gnome-disk-utility, which drags
        # in libqmi/modemmanager/sane for ~120 MB more.
        gparted
      ];

      # GTK sidebar bookmarks. A file entry, not the directory: home-manager owns
      # settings.ini and gtk.css inside ~/.config/gtk-3.0.
      preservation.preserveAt."/persistent".users.tguimbert.files = [ ".config/gtk-3.0/bookmarks" ];
    };

  homeManager.modules.gui = {
    # ~/Documents, ~/Downloads, … and the user-dirs.dirs GTK dialogs read for their
    # shortcuts; GNOME used to run xdg-user-dirs for this.
    xdg.userDirs = {
      enable = true;
      # home-manager's new default, pinned to silence the transition warning our
      # older home.stateVersion triggers. Only the XDG_*_DIR session variables are
      # dropped, which nothing here reads.
      setSessionVariables = false;
    };

    # Replaces the mimeapps.list GNOME injected via XDG_DATA_DIRS.
    xdg.mimeApps = {
      enable = true;
      defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";
    };
  };
}
