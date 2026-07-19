# Shared BTRFS-on-LUKS ephemeral-root disk layout.
#
# `_`-prefixed dir → skipped by import-tree; imported by relative path from each
# host's disks.nix (like hardware.nix). Root is a tmpfs (RAM-backed, empty every
# boot); only the persistent btrfs subvolumes survive. Hosts with extra disks
# (e.g. leshen) merge additional `disko.devices.disk.*` on top via `lib.mkMerge`.
{
  device ? "/dev/nvme0n1",
  swapSize ? "8G",
  rootSize ? "25%",
}:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      inherit device;
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
              mountOptions = [
                "defaults"
              ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "encrypted";
              settings = {
                allowDiscards = true;
              };
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
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile = {
                      size = swapSize;
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
          "size=${rootSize}"
          "mode=755"
        ];
      };
    };
  };

  fileSystems = {
    "/persistent".neededForBoot = true;
  };
}
