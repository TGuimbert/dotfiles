{
  lib,
  inputs,
  pkgs,
  config,
  ...
}:
let
  gv = lib.hm.gvariant;
in
{
  programs = {
    firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
      languagePacks = [
        "en-US"
        "fr"
      ];
      arkenfox = {
        enable = true;
        version = "144.0";
        profiles.default = {
          enableAllSections = true;
          settings = {
            "0100" = {
              enable = true;
              "0102"."browser.startup.page".value = 3;
              "0103"."browser.startup.homepage".value = "about:home";
              "0104"."browser.newtabpage.enabled".value = true;
            };
            "5500".enable = false;
          };
        };
      };
      profiles.default = {
        name = "default";
        settings = {
          "extensions.pocket.enabled" = false;
          "browser.ctrlTab.recentlyUsedOrder" = true;
        };
        search = {
          force = true;
          default = "ddg";
          privateDefault = "ddg";
          order = [
            "ddg"
            "google"
          ];
          engines = {
            "bing".metaData.hidden = true;
          };
        };
        containers = {
          google = {
            id = 1;
            name = "Google";
            color = "red";
            icon = "fingerprint";
          };
          work = {
            id = 2;
            name = "Work";
            color = "blue";
            icon = "briefcase";
          };
          twitch = {
            id = 3;
            name = "Twitch";
            color = "purple";
            icon = "chill";
          };
          proton = {
            id = 4;
            name = "Proton";
            color = "purple";
            icon = "fingerprint";
          };
        };
        containersForce = true;
        extensions.packages = with inputs.firefox-addons.packages.x86_64-linux; [
          ublock-origin
          bitwarden
          multi-account-containers
        ];
      };
    };

    chromium.enable = true;
  };

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

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "firefox.desktop" ];
      "text/xml" = [ "firefox.desktop" ];
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
    };
  };
}
