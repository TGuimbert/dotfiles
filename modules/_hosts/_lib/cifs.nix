# Builds a CIFS `fileSystems.<name>` entry for a `//nas.lan/<share>` mount.
#
# `_`-prefixed dir → skipped by import-tree; imported as a plain function by the
# aspects that mount NAS shares. Option order matches the historical joined
# string so the resulting (comma-joined) mount options are unchanged.
{
  share,
  credentials,
  uid ? "1000",
  gid ? "100",
  extraOptions ? [ ],
}:
{
  device = "//nas.lan/${share}";
  fsType = "cifs";
  options = [
    "x-systemd.automount"
    "noauto"
    "x-systemd.idle-timeout=60"
    "x-systemd.device-timeout=5s"
    "x-systemd.mount-timeout=5s"
    "credentials=${credentials}"
    "uid=${uid}"
    "gid=${gid}"
  ]
  ++ extraOptions;
}
