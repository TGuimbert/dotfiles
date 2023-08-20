{ pkgs, lib, ... }:

let
  username = "tguimbert";
in
with lib;
{
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";

  home.packages = with pkgs; [
    spotify
    yubikey-manager
    rage
    age-plugin-yubikey
    bitwarden-cli
    kubectl
    minikube
    kind
    discord
    vlc
    remmina
    anki-bin
    kochi-substitute-naga10
    libsForQt5.fcitx5-qt
    jetbrains.pycharm-community
    jetbrains.idea-community
    obsidian
    bitwarden
    bitwarden-cli
  ];

  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      libsForQt5.fcitx5-qt
    ];
  };
  home.sessionVariables.QT_IM_MODULE = lib.mkForce "fcitx anki";

  home.file = {
    minikubeConfig = mkDefault {
      target = ".minikube/config/config.json";
      text = builtins.toJSON {
        container-runtime = "containerd";
        rootless = true;
      };
    };
  };

  programs = {
    home-manager.enable = true;
    firefox.enable = true;
    k9s.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  xdg.mimeApps = {
    defaultApplications = {
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/chrome" = "firefox.desktop";
      "text/html" = "firefox.desktop";
      "application/x-extension-htm" = "firefox.desktop";
      "application/x-extension-html" = "firefox.desktop";
      "application/x-extension-shtml" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      "application/x-extension-xhtml" = "firefox.desktop";
      "application/x-extension-xht" = "firefox.desktop";
    };
    associations.added = {
      "x-scheme-handler/http" = "firefox.desktop;";
      "x-scheme-handler/https" = "firefox.desktop;";
      "x-scheme-handler/chrome" = "firefox.desktop;";
      "text/html" = "firefox.desktop;";
      "application/x-extension-htm" = "firefox.desktop;";
      "application/x-extension-html" = "firefox.desktop;";
      "application/x-extension-shtml" = "firefox.desktop;";
      "application/xhtml+xml" = "firefox.desktop;";
      "application/x-extension-xhtml" = "firefox.desktop;";
      "application/x-extension-xht" = "firefox.desktop;";
    };
  };
}
