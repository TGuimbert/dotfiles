{ pkgs, lib, ... }:
with lib; {
  virtualisation.podman.enable = mkForce false;

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
    autoPrune.enable = true;
  };
  users.users.tguimbert.extraGroups = [ "docker" ];

  environment.systemPackages = [
    pkgs.docker-compose
  ];
}
