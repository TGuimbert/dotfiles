{
  config,
  lib,
  modulesPath,
  ...
}:
{

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [ ];

      luks.devices."root".device = "/dev/disk/by-partlabel/LUKS";
    };

    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];

  };

  fileSystems = {
    "/" = {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [
        "subvol=root"
        "compress=zstd"
        "noatime"
      ];
    };

    "/boot" = {
      label = "BOOT";
      fsType = "vfat";
    };

    "/nix" = {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [
        "subvol=nix"
        "compress=zstd"
        "noatime"
      ];
    };

    "/persist-root" = {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [
        "subvol=persist-root"
        "compress=zstd"
        "noatime"
      ];
      neededForBoot = true;
    };

    "/persist-home" = {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [
        "subvol=persist-home"
        "compress=zstd"
        "noatime"
      ];
      neededForBoot = true;
    };

    "/home" = {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [
        "subvol=home"
        "compress=zstd"
        "noatime"
      ];
      neededForBoot = true;
    };

    "/var/log" = {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [
        "subvol=log"
        "compress=zstd"
        "noatime"
      ];
    };

    "/var/lib/docker" = {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [
        "subvol=docker"
        "compress=zstd"
        "noatime"
      ];
    };

    "/swap" = {
      label = "btrfs-toplevel";
      fsType = "btrfs";
      options = [
        "subvol=swap"
        "compress=zstd"
        "noatime"
      ];
    };
  };

  swapDevices = [ { device = "/swap/swapfile"; } ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
