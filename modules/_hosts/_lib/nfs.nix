# Builds an NFS `fileSystems.<mountpoint>` entry for a `nas.lan:<export>` mount.
#
# `_`-prefixed dir → skipped by import-tree; imported as a plain function by the
# aspects that mount NAS exports. NFS rather than the CIFS sibling for the media
# library: it carries real uid/gid instead of one faked mount identity shared by
# every service, and hardlinks and atomic renames work — which is what the *arr
# do on every import.
{
  export,
  server ? "nas.lan",
  extraOptions ? [ ],
}:
{
  device = "${server}:${export}";
  fsType = "nfs";
  options = [
    "nfsvers=4.2"
    # Automounted and `noauto`, so a NAS that is slow to come up delays the
    # first read rather than the boot. No `idle-timeout` (unlike ./cifs.nix):
    # unmounting under a paused stream is pointless churn.
    "x-systemd.automount"
    "noauto"
    # The default, affirmed: a NAS reboot then suspends a read until it answers
    # rather than failing it, and a playback that stalls beats a library that
    # reports itself empty and invites the *arr to re-import it.
    "hard"
    "noatime"
    "x-systemd.mount-timeout=10s"
  ]
  ++ extraOptions;
}
