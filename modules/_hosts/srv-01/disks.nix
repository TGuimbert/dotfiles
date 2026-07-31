# Bare-metal layout: unencrypted (headless box, no unattended-unlock story), so
# it does not share ../_lib/btrfs-disk.nix, which is BTRFS-on-LUKS. Root is a
# tmpfs; only the btrfs subvolumes below survive a reboot.
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # By-id: /dev/nvme0n1 is not stable across kernel/firmware changes and
        # disko writes the device into the generated fstab.
        device = "/dev/disk/by-id/nvme-PC611_NVMe_SK_hynix_512GB_NJ03N572411703G27";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              name = "EFI";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                # systemd-boot warns when the ESP is world-readable.
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/persistent" = {
                    mountpoint = "/persistent";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  # 15G of RAM, a quarter of which goes to the tmpfs root;
                  # matches the 8G the proxmox install had on pve-swap.
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile = {
                      size = "8G";
                      path = "swapfile";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=25%"
          "mode=755"
        ];
      };
    };
  };

  fileSystems."/persistent".neededForBoot = true;
}
