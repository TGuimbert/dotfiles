{ lib, ... }:

{
  imports = [
    ./hardware.nix
    ./disks.nix
  ];

  networking.hostName = "wyvern";

  tguimbert = {
    system = {
      secure-boot.enable = true;
      impermanence.enable = true;
      btrfs.enable = true;
    };
    virtualisation.containerPlatform = "docker";
    apps.slack.enable = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
