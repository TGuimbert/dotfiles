{ inputs, ... }:
{
  programs = {
    firefox = {
      enable = true;
      languagePacks = [
        "en-US"
        "fr"
      ];
      arkenfox = {
        enable = true;
        version = "133.0";
      };
      profiles.default = {
        name = "default";
        arkenfox = {
          enable = true;
          "0000".enable = true;
          "0100" = {
            enable = true;
            "0102"."browser.startup.page".value = 3;
            "0103"."browser.startup.homepage".value = "about:home";
            "0104"."browser.newtabpage.enabled".value = true;
          };
          "0200".enable = true;
          "0300" = {
            enable = true;
            "0360"."captivedetect.canonicalURL".enable = false;
            "0360"."network.captive-portal-service.enabled".enable = false;
            "0361"."network.connectivity-service.enabled".enable = false;
          };
          "0400".enable = false;
          "0600".enable = true;
          "0700".enable = true;
          "0800".enable = true;
          "0900".enable = true;
          "1000" = {
            enable = true;
            "1001"."browser.cache.disk.enable".enable = false;
          };
          "1200".enable = true;
          "1600".enable = true;
          "1700".enable = true;
          "2000".enable = true;
          "2400".enable = true;
          "2600".enable = true;
          "2700".enable = true;
          "2800" = {
            enable = true;
            "2811" = {
              "privacy.clearOnShutdown.history".value = false;
              "privacy.clearOnShutdown_v2.historyFormDataAndDownloads".value = false;
              # "privacy.clearHistory.browsingHistoryAndDownloads".value = false;
              # "privacy.clearOnShutdown_v2.browsingHistoryAndDownloads".value = false;
              # "privacy.clearOnShutdown_v2.downloads".value = true;
              # "privacy.clearSiteData.browsingHistoryAndDownloads".value = false;
            };
          };
          "4000".enable = false;
          "5000" = {
            enable = true;
            "5003"."signon.rememberSignons".enable = true;
          };
          "5500".enable = false;
          "6000".enable = true;
          "9000".enable = true;
        };
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
}
