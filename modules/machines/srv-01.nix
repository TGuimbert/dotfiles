{ config, ... }:
{
  nixos.configurations.srv-01.module = {
    imports =
      (with config.nixos.modules; [
        base
        server
        secureBoot
        autoUpgrade
        traefik
        authelia
        lldap
        homepage
        backup
        printScan
        homeAssistant
        gatus
        beszel
        ups
        mediaLibrary
        jellyfin
        servarr
        sabnzbd
        bazarr
        recyclarr
        jellyseerr
        grimmory
        shelfmark
        paperless
        mealie
        radicale
        couchdb
      ])
      ++ [
        ../_hosts/srv-01/hardware.nix
        ../_hosts/srv-01/disks.nix
      ];

    nixpkgs.hostPlatform = "x86_64-linux";

    system.stateVersion = "25.11";
  };
}
