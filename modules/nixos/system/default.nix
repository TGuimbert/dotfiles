{ pkgs, config, ... }:
{
  environment.systemPackages = [ pkgs.cifs-utils ];
  fileSystems."/mnt/share" = {
    device = "//192.168.1.100/Home";
    fsType = "cifs";
    options =
      let
        # this line prevents hanging on network split
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      [
        "${automount_opts},credentials=/run/secrets/smb-secrets,uid=${toString config.users.users.tguimbert.uid},gid=${toString config.users.groups.users.gid}"
      ];
  };
}
