{ ... }:
{
  config = {
    environment.persistence."/persist-root" = {
      hideMounts = true;
      directories = [
        "/var/lib/nixos"
        "/var/lib/fwupd"
        "/var/lib/systemd/coredump"
        "/var/lib/bluetooth"
        "/var/lib/boltd"
        "/var/lib/tailscale"
        "/etc/NetworkManager/system-connections"
        "/etc/secureboot"
      ];
      files = [
        "/etc/machine-id"
      ];
    };

    programs.fuse.userAllowOther = true;

    boot.initrd.systemd.services.rollback = {
      description = "Rollback BTRFS root subvolume to a pristine state";
      wantedBy = [
        "initrd.target"
      ];
      after = [
        # LUKS/TPM process
        "systemd-cryptsetup@root.service"
      ];
      before = [
        "sysroot.mount"
        "systemd-tmpfiles-setup.service"
      ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /mnt
        # We first mount the btrfs root to /mnt
        # so we can manipulate btrfs subvolumes.
        mount /dev/mapper/root /mnt

        echo "snapshotting the /root subvolume"
        btrfs subvolume delete /mnt/.snapshot/root-boot-2
        btrfs subvolume snapshot /mnt/.snapshot/root-boot-1 /mnt/.snapshot/root-boot-2
        btrfs subvolume delete /mnt/.snapshot/root-boot-1
        btrfs subvolume snapshot /mnt/root /mnt/.snapshot/root-boot-1

        echo "deleting /root subvolume..."
        btrfs subvolume delete /mnt/root

        echo "restoring blank /root subvolume..."
        btrfs subvolume snapshot /mnt/.snapshot/root-blank /mnt/root

        echo "snapshotting the /home subvolume"
        btrfs subvolume delete /mnt/.snapshot/home-boot-2
        btrfs subvolume snapshot /mnt/.snapshot/home-boot-1 /mnt/.snapshot/home-boot-2
        btrfs subvolume delete /mnt/.snapshot/home-boot-1
        btrfs subvolume snapshot /mnt/home /mnt/.snapshot/home-boot-1

        echo "deleting /home subvolume..."
        btrfs subvolume delete /mnt/home

        echo "restoring blank /home subvolume..."
        btrfs subvolume snapshot /mnt/.snapshot/home-blank /mnt/home

        # Once we're done rolling back to a blank snapshot,
        # we can unmount /mnt and continue on the boot process.
        umount /mnt
      '';
    };
  };
}
