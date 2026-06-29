{ inputs, ... }:
{
  homeManager.modules.gui =
    { config, ... }:
    {
      imports = [ inputs.arkenfox-nix.modules.homeManager.arkenfox ];

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
              skip-redirect
              bitwarden
              multi-account-containers
            ];
          };
        };

        chromium.enable = true;
      };

      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = [ "firefox.desktop" ];
          "text/xml" = [ "firefox.desktop" ];
          "x-scheme-handler/http" = [ "firefox.desktop" ];
          "x-scheme-handler/https" = [ "firefox.desktop" ];
        };
      };
    };
}
