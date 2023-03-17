{ pkgs, ... }:
{
  users.mutableUsers = false;
  users.users.tguimbert = {
    name = "tguimbert";
    description = "Thibault Guimbert";
    isNormalUser = true;
    isSystemUser = false;
    extraGroups = [ "networkmanager" "wheel" ];
    uid = 1000;
    shell = pkgs.bashInteractive;
    initialPassword = "password";
    passwordFile = "/persist-root/tguimbert-password";
  };

  security.sudo.extraConfig = "Defaults lecture=\"never\"";
}
