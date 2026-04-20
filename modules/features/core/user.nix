{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.features.user.enable = lib.mkEnableOption "user configuration" // {
    default = true;
  };

  config = lib.mkIf config.features.user.enable {
    users = {
      mutableUsers = false;
      users.tguimbert = {
        name = "tguimbert";
        description = "Thibault Guimbert";
        isNormalUser = true;
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        uid = 1000;
        shell = pkgs.bashInteractive;
        hashedPasswordFile = "/persistent/tguimbert-password";
      };
    };

    security.sudo.extraConfig = "Defaults lecture=\"never\"";
  };
}
