{ pkgs, config, lib, ... }:
with lib;
let
  cfg = config.tguimbert.apps.slack;
  username = config.tguimbert.user.name;
in
{
  options.tguimbert.apps.slack = {
    enable = mkEnableOption "Whether to enable support for Slack.";
  };
  config = mkIf cfg.enable {
    environment = {
      systemPackages = with pkgs; [ slack ];
    };
    xdg = {
      portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gnome
        ];
      };
    };
    snowfallorg = mkIf config.tguimbert.system.impermanence.enable {
      users.${username}.home.config = {
        home.persistence."/persistent/home/${username}" = {
          directories = [
            ".config/Slack"
          ];
        };
      };
    };
  };
}
