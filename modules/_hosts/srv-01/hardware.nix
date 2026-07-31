# Minimal hand-written stub for the bare-metal install: enough to boot the NVMe
# root. Replaced by `hardware.facter.reportPath = ./facter.json;` (as on
# leshen/griffin) once facter can be run on the installed machine.
{ lib, ... }:

{
  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  hardware.enableRedistributableFirmware = true;

  # Swap comes from the btrfs swapfile in disks.nix.
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
