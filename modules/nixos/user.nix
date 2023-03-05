{ pkgs, ... }:

{
  users.users.tguimbert = {
    name = "tguimbert";
    description = "Thibault Guimbert";
    isNormalUser = true;
    isSystemUser = false;
    extraGroups = [ "networkmanager" "wheel" ];
    uid = 1000;
    initialPassword = "password";
    shell = pkgs.bashInteractive;
  };
}
