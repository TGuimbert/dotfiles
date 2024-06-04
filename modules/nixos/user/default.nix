{ config, lib, pkgs, ... }:
with lib;
let cfg = config.tguimbert.user;
in
{
  options.tguimbert.user = {
    name = mkOption {
      type = types.str;
      default = "tguimbert";
      description = "The name of the user account.";
    };
  };
  config = {
    users.mutableUsers = false;
    users.users.tguimbert = {
      inherit (cfg) name;
      description = "Thibault Guimbert";
      isNormalUser = true;
      isSystemUser = false;
      extraGroups = [ "networkmanager" "wheel" ];
      uid = 1000;
      shell = pkgs.bashInteractive;
      hashedPasswordFile = "/persistent/tguimbert-password";
    };

    security.sudo.extraConfig = "Defaults lecture=\"never\"";
  };
}
