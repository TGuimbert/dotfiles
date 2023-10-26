{ config, lib, modulesPath, ... }:

{
  networking.hostName = "leshen";

  tguimbert = {
    system.boot.secureBoot = true;
    virtualisation.containerPlatform = "podman";
  };

  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [ ];

  boot.initrd.luks.devices."root".device = "/dev/disk/by-partlabel/LUKS";

  fileSystems."/" =
    {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" "noatime" ];
    };

  fileSystems."/boot" =
    {
      label = "BOOT";
      fsType = "vfat";
    };

  fileSystems."/nix" =
    {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" "noatime" ];
    };

  fileSystems."/persist-root" =
    {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [ "subvol=persist-root" "compress=zstd" "noatime" ];
      neededForBoot = true;
    };

  fileSystems."/persist-home" =
    {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [ "subvol=persist-home" "compress=zstd" "noatime" ];
      neededForBoot = true;
    };

  fileSystems."/home" =
    {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [ "subvol=home" "compress=zstd" "noatime" ];
      neededForBoot = true;
    };

  fileSystems."/var/log" =
    {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [ "subvol=log" "compress=zstd" "noatime" ];
    };

  fileSystems."/swap" =
    {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [ "subvol=swap" "compress=zstd" "noatime" ];
    };

  swapDevices = [{ device = "/swap/swapfile"; }];

  services.btrfs.autoScrub.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
