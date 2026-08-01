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
  # Unlock from the TPM instead of a passphrase, for hosts with no keyboard at
  # boot. Enrol at runtime with systemd-cryptenroll against PCR 7 — which
  # measures Secure Boot state, so it has to happen *after* the lanzaboote keys
  # are in the firmware or the sealed policy stops matching the moment they are.
  tpm2Unlock ? false,
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
              # vfat has no permission bits of its own, so "defaults" leaves the
              # ESP world-readable — and bootctl warns that the random seed it
              # backs is then exposed to any local user.
              mountOptions = [
                "umask=0077"
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

  boot.initrd.luks.devices.encrypted.crypttabExtraOpts =
    if tpm2Unlock then [ "tpm2-device=auto" ] else [ ];
}
