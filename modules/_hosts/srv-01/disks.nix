{ lib, ... }:
lib.mkMerge [
  (import ../_lib/btrfs-disk.nix {
    # By-id: /dev/nvme0n1 is not stable across kernel/firmware changes and disko
    # writes the device into the generated fstab. The 8G swap and 25% tmpfs root
    # defaults suit the box as-is (15G of RAM, matching the old pve-swap).
    device = "/dev/disk/by-id/nvme-PC611_NVMe_SK_hynix_512GB_NJ03N572411703G27";
  })
  {
    # The box is headless, so nothing can type a passphrase at boot. Unlock from
    # the TPM instead, enrolled at runtime with systemd-cryptenroll against PCR 7
    # (Secure Boot state) — which means enrolling *after* the lanzaboote keys are
    # in the firmware, or the sealed policy stops matching the moment they are.
    # The passphrase set at disko time stays as the fallback slot.
    boot.initrd.luks.devices.encrypted.crypttabExtraOpts = [ "tpm2-device=auto" ];
  }
]
