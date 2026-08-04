{ ... }:
{
  # The library itself: one NFS export from the NAS, read by ./jellyfin.nix and
  # written by ./servarr.nix, declared here so the two cannot drift apart on
  # where it is mounted or which group reaches it. Why the bytes live on the NAS
  # while the work happens here: ../../CLAUDE.md, "Media on srv-01".
  nixos.modules.mediaLibrary =
    { ... }:
    let
      dir = "/mnt/media";
    in
    {
      # Read back from the NAS (`stat` a file the export created), not chosen —
      # TrueNAS allocated 3006, not the 3000 its range starts at. It has to
      # match: the export maps every request to media:media, so a number picked
      # here would put jellyfin and the *arr in a group matching nothing.
      users.groups.media.gid = 3006;

      fileSystems.${dir} = import ../_hosts/_lib/nfs.nix {
        export = "/mnt/main/media/video";
      };

      # Same `_module.args` idiom as ./traefik-router.nix and ./gatus.nix: one
      # definition, consumed by the aspects that need it. An aspect reading this
      # will not evaluate on a host that omits `mediaLibrary`, which is the loud
      # failure rather than a service pointed at an empty directory.
      _module.args.mediaLibrary = {
        inherit dir;
        group = "media";
      };
    };
}
