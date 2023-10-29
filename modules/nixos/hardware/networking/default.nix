{ lib, ... }:
with lib;
{
  config = {
    networking.networkmanager.enable = true;
    networking.useDHCP = mkDefault true;
  };
}
