{ ... }:
{
  nixos.modules.autoUpgrade = {
    system.autoUpgrade = {
      enable = true;
      flake = "github:TGuimbert/dotfiles";
      flags = [ "--print-build-logs" ];

      dates = "03:00";
      randomizedDelaySec = "20min";

      allowReboot = true;
      rebootWindow = {
        lower = "03:00";
        upper = "05:00";
      };
    };
  };
}
