{ ... }:
{
  nixos.modules.desktop =
    { pkgs, ... }:
    {
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      # headsetcontrol ships lib/udev/rules.d/70-headsets.rules, which tags the
      # headset's hidraw node `uaccess`; without it every query needs root. The
      # Arctis 7 (1038:12ad) is in that file's "Arctis (7/Pro)" block, not the
      # similarly named "Arctis (1/7X/7P) Wireless" one.
      services.udev.packages = [ pkgs.headsetcontrol ];

      preservation.preserveAt."/persistent".users.tguimbert.directories = [
        ".local/state/wireplumber"
      ];
    };

  homeManager.modules.gui =
    { pkgs, ... }:
    {
      # No system-wide mic processing, deliberately: Discord's Krisp covers the
      # only voice calls these hosts make, so OBS and browser calls get the raw
      # mic. Krisp does work in Vesktop despite the widespread claim it doesn't —
      # that claim is about `discord_krisp.node`, the native module Vesktop has no
      # need of, being the web build. EasyEffects was tried and removed (see git).

      # Sidetone, battery and chatmix for the Arctis 7 (`headsetcontrol -o json`);
      # nothing it sets survives a power-cycle.
      home.packages = [ pkgs.headsetcontrol ];
    };
}
