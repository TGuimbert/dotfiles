{ ... }:
{
  # srv-01 backs nothing up itself: it stages a consistent copy of its service
  # state — lldap, authelia, the *arr and jellyfin's config — and the TrueNAS
  # *pulls* that over SFTP, so nothing here holds a credential that reaches the
  # backups. The media itself is never in scope: it lives on the NAS already. Retention is the NAS's snapshot task;
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
      jellyfinDir = config.services.jellyfin.dataDir;

      # Staged wholesale. Jellyfin is not in the list: most of its data dir is a
      # metadata image cache, so it gets its own rsync with that excluded.
      stateDirs = [
        "/var/lib/lldap"
        "/var/lib/authelia-main"
        "/var/lib/sonarr"
        "/var/lib/radarr"
        "/var/lib/prowlarr"
        # Language profiles, provider logins and what has already been fetched.
        "/var/lib/bazarr"
        # Requests, and the Jellyfin accounts allowed to make them.
        "/var/lib/jellyseerr"
        # Everything ./shelfmark.nix cannot express as an environment variable,
        # plus the users and their requests.
        "/var/lib/shelfmark"
      ];
      # Not here on purpose: sabnzbd, whose state is a re-downloadable queue, and
      # recyclarr, whose directory is a clone of the TRaSH guides plus a config
      # generated from ./recyclarr.nix. Both rebuild themselves.

      # Live sqlite databases: dumped rather than copied, and excluded from the
      # rsyncs above for the same reason. All sit under /var/lib and the staging
      # tree mirrors it, so the destinations are derived rather than restated.
      dumps = [
        "/var/lib/lldap/users.db"
        autheliaDb
        "${config.services.sonarr.dataDir}/sonarr.db"
        "${config.services.radarr.dataDir}/radarr.db"
        "${config.services.prowlarr.dataDir}/prowlarr.db"
        "${jellyfinDir}/data/jellyfin.db"
        "${jellyfinDir}/data/library.db"
        "${config.services.bazarr.dataDir}/db/bazarr.db"
        "${config.services.seerr.configDir}/db/db.sqlite3"
        "/var/lib/shelfmark/users.db"
      ];

      # Grimmory's library metadata, users and OIDC client. The only thing staged
      # here that is not sqlite, and the only configuration in the backup that a
      # rebuild cannot reproduce — ../../CLAUDE.md, "Books on srv-01".
      grimmoryDb = "grimmory";
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
            # For `mariadb-dump` below — the client half of the same package
            # ./grimmory.nix runs the server from.
            config.services.mysql.package
            # `runuser`, for the same dump.
            pkgs.util-linux
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
            for src in ${lib.concatStringsSep " " stateDirs}; do
              rsync -a --delete --chown=nas-backup:nas-backup \
                --exclude='*.db' --exclude='*.db-*' \
                --exclude='*.sqlite3' --exclude='*.sqlite3-*' \
                "$src"/ ${stagingDir}/"$(basename "$src")"/
            done

            # Most of jellyfin's data dir is artwork it re-fetches on demand.
            # Worth pulling: the config, the plugins, and the two databases
            # below — users, libraries and watch history.
            rsync -a --delete --chown=nas-backup:nas-backup \
              --exclude='metadata/' --exclude='transcodes/' --exclude='log/' \
              --exclude='*.db' --exclude='*.db-*' \
              ${jellyfinDir}/ ${stagingDir}/jellyfin/

            # The smaller half of Grimmory: the library metadata is in the
            # MariaDB dump below, not here. `images/` is deliberately kept —
            # unlike jellyfin's artwork above it can hold covers uploaded by
            # hand, which nothing re-fetches. `bookdrop_temp/` is staging for an
            # import in flight, and `.hprof` is a heap dump someone enabled to
            # debug an OOM; neither is worth carrying nightly.
            rsync -a --delete --chown=nas-backup:nas-backup \
              --exclude='cache/' --exclude='bookdrop_temp/' --exclude='*.hprof' \
              /var/lib/grimmory/ ${stagingDir}/grimmory/

            # .backup rather than a file copy: the online-backup API is the only
            # way to snapshot a database its service holds open.
            for db in ${lib.concatStringsSep " " dumps}; do
              dest=${stagingDir}/''${db#/var/lib/}
              sqlite3 "$db" ".backup '$dest'"
              chown nas-backup:nas-backup "$dest"
            done

            # --single-transaction so this can run while Grimmory is serving.
            # `runuser` because MariaDB's superuser is the *`mysql` OS user*:
            # unix_socket authenticates whoever opened the socket, so root is
            # refused. The redirect stays in the root shell, which is what can
            # write to the destination.
            install -d -o nas-backup -g nas-backup -m 0750 ${stagingDir}/mysql
            runuser -u ${config.services.mysql.user} -- \
              mariadb-dump --single-transaction --databases ${grimmoryDb} \
              > ${stagingDir}/mysql/${grimmoryDb}.sql
            chown nas-backup:nas-backup ${stagingDir}/mysql/${grimmoryDb}.sql
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
