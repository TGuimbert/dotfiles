{ ... }:
{
  nixos.modules.desktop = {
    # Snapshot targets for the initrd rollback below (the /persistent dirs come
    # from preservation).
    systemd.tmpfiles.settings.btrfs-rollback = {
      "/.snapshot/root".d = {
        user = "root";
        group = "root";
        mode = "0755";
      };
      "/.snapshot/home".d = {
        user = "root";
        group = "root";
        mode = "0755";
      };
    };

    boot.initrd.systemd.services.rollback = {
      description = "Rollback BTRFS root and home subvolume to a pristine state";
      wantedBy = [
        "initrd.target"
      ];
      after = [
        # LUKS/TPM process
        "systemd-cryptsetup@encrypted.service"
      ];
      before = [
        "sysroot.mount"
      ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        echo "Mounting the BTRFS partition"
        mkdir /btrfs_tmp
        mount /dev/mapper/encrypted /btrfs_tmp

        if [[ -e /btrfs_tmp/root ]]; then
          echo "Moving the root subvolume in snapshot"
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          mv /btrfs_tmp/root "/btrfs_tmp/snapshot/root/$timestamp"
          echo "Recreating the root subvolume"
          btrfs subvolume create /btrfs_tmp/root
        fi

        if [[ -e /btrfs_tmp/home ]]; then
          echo "Moving the home subvolume in snapshot"
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/home)" "+%Y-%m-%-d_%H:%M:%S")
          mv /btrfs_tmp/home "/btrfs_tmp/snapshot/home/$timestamp"
          echo "Recreating the home subvolume"
          btrfs subvolume create /btrfs_tmp/home
        fi

        delete_subvolume_recursively() {
            IFS=$'\n'
            for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                delete_subvolume_recursively "/btrfs_tmp/$i"
            done
            btrfs subvolume delete "$1"
        }

        echo "Deleting the root subvolume"
        for i in $(find /btrfs_tmp/snapshot/root/ -maxdepth 1 -mtime +15); do
            delete_subvolume_recursively "$i"
        done
        echo "Deleting the home subvolume"
        for i in $(find /btrfs_tmp/snapshot/home/ -maxdepth 1 -mtime +30); do
            delete_subvolume_recursively "$i"
        done

        umount /btrfs_tmp
      '';
    };
  };
}
