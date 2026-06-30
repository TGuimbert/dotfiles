# Shared BTRFS-on-LUKS impermanence disk layout.
#
# `_`-prefixed dir → skipped by import-tree; imported by relative path from each
# host's disks.nix (like hardware.nix). Returns the common `main` disk + tmpfs
# `/tmp` + boot-needed filesystems. Hosts with extra disks (e.g. leshen) merge
# additional `disko.devices.disk.*` on top via `lib.mkMerge`.
{
  device ? "/dev/nvme0n1",
  swapSize ? "8G",
  tmpfsSize ? "200M",
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
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
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
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/snapshot" = {
                    mountpoint = "/.snapshot";
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
      "/tmp" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=${tmpfsSize}"
        ];
      };
    };
  };

  fileSystems = {
    "/persistent".neededForBoot = true;
    "/home".neededForBoot = true;
  };
}
