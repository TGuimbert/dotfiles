{ config, lib, modulesPath, ... }:

{
  networking.hostName = "griffin";

  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "usbhid" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
  ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [
    # Workaround for the TPM interrupt message during boot.
    # See https://bugzilla.kernel.org/show_bug.cgi?id=204121.
    "tpm_tis.interrupts=0"
  ];

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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
