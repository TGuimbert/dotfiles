# /dev/nvme0n1 is not stable across kernel/firmware changes and disko bakes the
# device into the generated fstab, so address the disk by id.
import ../_lib/btrfs-disk.nix {
  device = "/dev/disk/by-id/nvme-PC611_NVMe_SK_hynix_512GB_NJ03N572411703G27";
  tpm2Unlock = true;
}
