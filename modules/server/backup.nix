{ ... }:
{
  # srv-01 backs nothing up itself: it stages a consistent copy of its service
  # state and the TrueNAS *pulls* that over SFTP, so nothing here holds a
  # credential that reaches the backups. Retention is the NAS's snapshot task;
  # restores are in ../../README.md.
  nixos.modules.backup =
    {
      config,
      lib,
      mkHeartbeat,
      pkgs,
      ...
    }:
    let
      # The chroot root has to stay root-owned, so the payload the NAS reads sits
      # one level down — it sees stagingDir as `/data`.
      chrootDir = "/var/backup";
      stagingDir = "${chrootDir}/data";

      # Public half of the keypair the Cloud Sync Task authenticates with:
      # TrueNAS > Credentials > Backup Credentials > SSH Keypairs.
      nasPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJwESZBSTDocBgb7AY/WiTUut68JivrSkJ/XWVu9KB2YJ1yxAzaVzsUMeKlC3R3foF128uDBRv3rlMI57iJJKkLnVKt6ZozrkXD7H8Ttqhx2sBdnS6fzsHq0XyLoJsCGolvFU2CSDyhdG/F44akLsTTJC2WtvZqXONamQPEvPXQZWrBiLHARsCzgCix3bkYfqYd9hCKLFvpPHLUeMNukdUezVQpzA9MBBsaHq9Na+qve2eN4RpLdZeYPuwhjlAVG1ZDa6azX6WoHjOp+ASg4/vg5fAdOqJz92tp8svnqUxkF+CQ1pkNd6iDw/JQHAsisa+8Yn6mdcKXP5pFuTYmItZHQ/+XPm5mHy6ephEosBhWA2xLFU1rCsdmJP96jLTNErVjCgxIU9cmoKJ8/Rz/mhOS/EMMm4iyavimRZGbCkq/RF3nPFkfdXP5tnkauCrsYe52TfOafHzFz+Z2807VDtpZKZG3WOxHZUTmzkr4bNG+qdZ5pX44tQd/rx0FkBxdvM= truenas-cloudsync";

      # Read back rather than re-typed, so it cannot drift out of step with the
      # aspect that owns it and leave this dumping a path that no longer exists.
      autheliaDb = config.services.authelia.instances.main.settings.storage.local.path;
    in
    {
      users = {
        users.nas-backup = {
          isSystemUser = true;
          group = "nas-backup";
          # Chosen rather than recorded like the sibling aspects' ids — this
          # account is new. 350 is clear of both allocators: nixpkgs' static ids
          # stop at 326, NixOS' dynamic ones run from 999 down.
          uid = 350;
          # Becomes the chroot root once sshd has chrooted.
          home = "/";
          openssh.authorizedKeys.keys = [
            # sshd matches `from=` against the address a connection actually
            # arrives on, so every address the NAS might pull from is listed.
            ''restrict,from="10.0.0.55,10.0.0.56" ${nasPublicKey}''
          ];
        };
        groups.nas-backup.gid = 350;
      };

      # ChrootDirectory confines the pull to one directory and `-R` makes
      # sftp-server refuse every write, so the NAS's key is read-only and sees
      # nothing else on the host.
      #
      # mkAfter keeps this last: a Match captures every directive after it, so a
      # *global* directive added at mkAfter elsewhere would land inside this block
      # and silently apply to nas-backup alone. Noted in ../services.nix too.
      services.openssh.extraConfig = lib.mkAfter ''
        Match User nas-backup
          ChrootDirectory ${chrootDir}
          ForceCommand internal-sftp -R
          AllowTcpForwarding no
          X11Forwarding no
      '';

      systemd = {
        services.backup-stage = {
          description = "Stage srv-01 service state for the TrueNAS pull";
          path = [
            pkgs.rsync
            pkgs.sqlite
          ];
          # Reports the outcome to ./gatus.nix, which alerts both when this fails
          # and when it stops running at all — the NAS mirrors deletions, so a
          # stage that silently stopped is as bad as one that broke.
          serviceConfig = {
            Type = "oneshot";
          }
          // mkHeartbeat "backup-stage";
          script = ''
            # sshd refuses a chroot it does not own, so only `data` beneath it
            # belongs to nas-backup.
            install -d -o root -g root -m 0755 ${chrootDir}
            install -d -o nas-backup -g nas-backup -m 0750 ${stagingDir}

            # Live sqlite files are excluded rather than copied — rsync would
            # catch them mid-write. Excluded files are not deleted from the
            # destination either, so the dumps below survive the next run.
            for src in /var/lib/lldap /var/lib/authelia-main; do
              rsync -a --delete --chown=nas-backup:nas-backup \
                --exclude='*.db' --exclude='*.db-*' \
                --exclude='*.sqlite3' --exclude='*.sqlite3-*' \
                "$src"/ ${stagingDir}/"$(basename "$src")"/
            done

            # .backup rather than a file copy: the online-backup API is the only
            # way to snapshot a database its service holds open.
            sqlite3 /var/lib/lldap/users.db ".backup '${stagingDir}/lldap/users.db'"
            sqlite3 ${autheliaDb} ".backup '${stagingDir}/authelia-main/db.sqlite3'"
            chown nas-backup:nas-backup \
              ${stagingDir}/lldap/users.db ${stagingDir}/authelia-main/db.sqlite3
          '';
        };

        timers.backup-stage = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            # Ahead of the NAS's pull, and clear of the 03:00-05:00 window
            # ../auto-upgrade.nix may reboot in.
            OnCalendar = "01:00";
            Persistent = true;
          };
        };
      };

      # Preserved so a reboot cannot leave an empty source for the next pull to
      # mirror — the NAS syncs deletions, so an empty source empties its copy.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = chrootDir;
          mode = "0755";
        }
      ];
    };
}
