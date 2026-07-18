{ ... }:
{
  nixos.modules.desktop =
    { pkgs, ... }:
    {
      services = {
        xserver.enable = true;
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;
        gnome.gcr-ssh-agent.enable = false;
      };

      environment = {
        gnome.excludePackages = with pkgs; [ gnome-tour ];
        systemPackages = with pkgs; [ wl-clipboard ];
      };

      preservation.preserveAt."/persistent".users.tguimbert = {
        directories = [ ".local/share/keyrings" ];
        files = [ ".config/monitors.xml" ];
      };
    };

  homeManager.modules.gui =
    {
      lib,
      pkgs,
      ...
    }:
    let
      gv = lib.hm.gvariant;
    in
    {
      dconf = {
        enable = true;
        settings = {
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
              "org.gnome.Nautilus.desktop"
            ];
          };
          "org/gnome/mutter".workspaces-only-on-primary = gv.mkValue false;
          "org/gnome/settings-daemon/plugins/housekeeping".donation-reminder-enabled = gv.mkValue false;
        };
      };

      home.file.".local/share/applications/ssh-askpass.desktop".text = ''
        [Desktop Entry]
        Name=SSH Askpass
        GenericName=ssh-askpass
        Type=Application
        Exec=${pkgs.seahorse}/libexec/seahorse/ssh-askpass
        Icon=seahorse
        NoDisplay=true
      '';

    };
}
