{ lib, ... }:
{
  imports = [ ./hardware.nix ];

  networking.hostName = "leshen";

  tguimbert = {
    system = {
      secure-boot.enable = true;
      impermanence.enable = true;
      btrfs.enable = true;
    };
    virtualisation.containerPlatform = "podman";
    suites = {
      games.enable = true;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}