{ pkgs, config, ... }:
{
  sops.secrets = {
    resticPassword = { };
    resticEnvironment = { };
  };
  services.restic.backups.nas = {
    repository = "s3:https://garage.home.guimbert.fr/restic-backup";
    passwordFile = config.sops.secrets.resticPassword.path;
    environmentFile = config.sops.secrets.resticEnvironment.path;
    paths = [
      "/var/lib/private/lldap"
      "/var/lib/authelia-main"
      "/var/backup"
    ];
    backupPrepareCommand = ''
      mkdir -p /var/backup/sqldumps
      ${pkgs.sqlite}/bin/sqlite3 /var/lib/private/lldap/users.db ".backup '/var/backup/sqldumps/lldap.bak'"
      ${pkgs.sqlite}/bin/sqlite3 /var/lib/authelia-main/db.sqlite3 ".backup '/var/backup/sqldumps/authelia.bak'"
    '';
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
      "--keep-yearly 1"
    ];
    extraBackupArgs = [
      "--tag srv-01"
      "--compression max"
    ];
  };
  environment.persistence."/persistent" = {
    directories = [
      "/var/backup/sqldumps"
      "/var/cache/restic"
    ];
  };
}
