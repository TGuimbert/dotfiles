{ pkgs, lib, ... }:
with lib;
{
  home = {
    packages = with pkgs; [
      kochi-substitute-naga10
      libsForQt5.fcitx5-qt
    ];

    sessionVariables.QT_IM_MODULE = mkForce "fcitx anki";
  };

  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      libsForQt5.fcitx5-qt
    ];
  };
}
