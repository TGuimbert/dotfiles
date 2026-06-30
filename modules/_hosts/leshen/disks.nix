{ lib, ... }:
lib.mkMerge [
  (import ../_lib/btrfs-disk.nix { })
  {
    disko.devices.disk = {
      secondary = {
        type = "disk";
        device = "/dev/sdb";
        content = {
          type = "gpt";
          partitions = {
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "encrypted-secondary";
                initrdUnlock = false;
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "/main" = {
                      mountpoint = "/ssd";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                  };
                };
              };
            };
          };
        };
      };
      tertiary = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "encrypted-tertiary";
                initrdUnlock = false;
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "/main" = {
                      mountpoint = "/hdd";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };

    environment.etc."crypttab".text = ''
      encrypted-secondary /dev/disk/by-partlabel/disk-secondary-luks /persistent/key/secondary
      encrypted-tertiary /dev/disk/by-partlabel/disk-tertiary-luks /persistent/key/tertiary
    '';
  }
]
