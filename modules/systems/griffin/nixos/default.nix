{ config, lib, pkgs, modulesPath, ... }:

{

  networking.hostName = "griffin";

  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/911f11f3-b84d-4d6f-b0b4-522bca4975a9";
      fsType = "ext4";
    };

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
		# Workaround for the TPM interrupt message during boot.
		# See https://bugzilla.kernel.org/show_bug.cgi?id=204121.
    "tpm_tis.interrupts=0"
  ];
  boot.extraModulePackages = [ ];


  # Enable swap on luks
  boot.initrd.luks.devices."luks-7e766608-b9fa-4bab-a69e-5aa8c7348cf8".device = "/dev/disk/by-uuid/7e766608-b9fa-4bab-a69e-5aa8c7348cf8";
  boot.initrd.luks.devices."luks-7e766608-b9fa-4bab-a69e-5aa8c7348cf8".keyFile = "/crypto_keyfile.bin";

  boot.initrd.luks.devices."luks-b54b338a-c777-47a0-ab7b-8152601887a6".device = "/dev/disk/by-uuid/b54b338a-c777-47a0-ab7b-8152601887a6";

  fileSystems."/boot/efi" =
    { device = "/dev/disk/by-uuid/DD2F-26E9";
      fsType = "vfat";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/933c3091-71fd-4738-9ed5-de1f3565e576"; }
    ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
