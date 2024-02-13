{ lib, config, ... }:
with lib;
let
  cfg = config.tguimbert.system.impermanence;
in
{
  options.tguimbert.system.impermanence = {
    enable = mkEnableOption "Whether to enable impermanence.";
  };
  config = mkIf cfg.enable {
    environment.persistence."/persistent" = {
      hideMounts = true;
      directories = [
        "/var/lib/nixos"
        "/var/lib/fwupd"
        "/var/lib/systemd/coredump"
        "/var/lib/bluetooth"
        "/var/lib/boltd"
        "/var/lib/tailscale"
        "/etc/NetworkManager/system-connections"
      ];
      files = [
        "/etc/machine-id"
      ];
    };

    programs.fuse.userAllowOther = true;

    system.activationScripts.persistentHome.text = ''
      install -d -m 0755 -o root -g root /persistent/home/
      install -d -m 0700 -o tguimbert -g users /persistent/home/tguimbert
    '';

    boot.initrd.systemd.services.rollback = {
      description = "Rollback BTRFS root and home subvolume to a pristine state";
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
        mkdir /btrfs_tmp
        mount /dev/mapper/encrypted /btrfs_tmp

        if [[ -e /btrfs_tmp/root ]]; then
            timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
            mv /btrfs_tmp/root "/btrfs_tmp/snapshot/root/$timestamp"
        fi
        if [[ -e /btrfs_tmp/home]]; then
            timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/home)" "+%Y-%m-%-d_%H:%M:%S")
            mv /btrfs_tmp/home "/btrfs_tmp/snapshot/home/$timestamp"
        fi

        delete_subvolume_recursively() {
            IFS=$'\n'
            for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                delete_subvolume_recursively "/btrfs_tmp/$i"
            done
            btrfs subvolume delete "$1"
        }

        for i in $(find /btrfs_tmp/snapshot/root/ -maxdepth 1 -mtime +15); do
            delete_subvolume_recursively "$i"
        done
        for i in $(find /btrfs_tmp/snapshot/home/ -maxdepth 1 -mtime +30); do
            delete_subvolume_recursively "$i"
        done

        btrfs subvolume create /btrfs_tmp/root
        btrfs subvolume create /btrfs_tmp/home

        umount /btrfs_tmp
      '';
    };
  };
}
