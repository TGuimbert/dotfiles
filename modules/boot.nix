{ ... }:
{
  # /tmp is disk-backed (a preservation bind-mount) rather than tmpfs, so builds
  # don't consume the tmpfs root's RAM; wiped each boot.
  nixos.modules.base.boot = {
    tmp = {
      useTmpfs = false;
      cleanOnBoot = true;
    };

    # Required by the `inInitrd` entries in ./preservation.nix.
    initrd.systemd.enable = true;
  };

  nixos.modules.desktop = {
    boot = {
      binfmt.emulatedSystems = [ "aarch64-linux" ];

      plymouth.enable = true;
      # Enable "Silent Boot"
      consoleLogLevel = 0;
      initrd.verbose = false;
      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
      ];
    };
  };
}
