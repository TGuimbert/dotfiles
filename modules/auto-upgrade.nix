{ ... }:
{
  nixos.modules.autoUpgrade =
    { mkHeartbeat, ... }:
    {
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

      # Reports the outcome to server/gatus.nix, so a failed run — or one that
      # stops happening — notifies rather than waiting to be noticed in the
      # journal. A run that reboots for a kernel change may not reach
      # ExecStopPost, hence the deliberately wide interval declared there.
      systemd.services.nixos-upgrade.serviceConfig = mkHeartbeat "nixos-upgrade";
    };
}
