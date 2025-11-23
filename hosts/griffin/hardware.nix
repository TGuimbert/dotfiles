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
        "sdhci_pci"
      ];
      kernelModules = [ ];
    };

    kernelModules = [
      "kvm-intel"
    ];
    extraModulePackages = [ ];
    kernelParams = [
      # Workaround for the TPM interrupt message during boot.
      # See https://bugzilla.kernel.org/show_bug.cgi?id=204121.
      "tpm_tis.interrupts=0"
    ];
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
