{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.features.boot.enable = lib.mkEnableOption "boot configuration" // {
    default = true;
  };

  config = lib.mkIf config.features.boot.enable {
    boot = {
      loader = {
        systemd-boot.enable = false;
        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = "/boot";
        };
        timeout = 0;
      };
      lanzaboote = {
        enable = true;
        pkiBundle = "/etc/secureboot";
      };
      bootspec.enable = true;
      tmp.useTmpfs = true;
      initrd.systemd.enable = true;
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

    environment.systemPackages = [ pkgs.sbctl ];
  };
}
