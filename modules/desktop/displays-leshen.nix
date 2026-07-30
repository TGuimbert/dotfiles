# leshen's fixed display setup: two DisplayPort monitors and the DDC/CI stack
# noctalia needs to drive their brightness. Opt-in aspect (`displaysLeshen`),
# imported from modules/machines/leshen.nix only — griffin's panel and dock
# monitors are left to niri's autodetection.
{ config, ... }:
{
  nixos.modules.displaysLeshen =
    { pkgs, ... }:
    {
      # Bridge the matching home-manager aspect onto this host (mirrors the `gui`
      # bridge in modules/users.nix).
      home-manager.users.tguimbert.imports = [ config.homeManager.modules.displaysLeshen ];

      # External-monitor brightness: leshen has no internal panel, so noctalia
      # drives the displays over DDC/CI (via ddcutil + i2c-dev) instead of sysfs
      # backlight. tguimbert joins the `i2c` group for unprivileged access. DDC/CI
      # must be enabled in each monitor's OSD; verify with `ddcutil detect` (both
      # DP outputs should report VCP 0x10).
      hardware.i2c.enable = true;
      users.users.tguimbert.extraGroups = [ "i2c" ];
      environment.systemPackages = [ pkgs.ddcutil ];
    };

  # Dual 2560x1440 @ scale 1, side by side. DP-1 (XF270HU, 144 Hz + VRR) is
  # the primary on the left; DP-2 (VG270U, 75 Hz) sits to its right.
  # position.x is in logical pixels (scale 1 here, so 2560 == panel width).
  homeManager.modules.displaysLeshen.programs.niri.settings.outputs = {
    "DP-1" = {
      mode = {
        width = 2560;
        height = 1440;
        refresh = 143.856;
      };
      scale = 1.0;
      position = {
        x = 0;
        y = 0;
      };
      # on-demand = VRR only for fullscreen VRR windows (games); avoids the
      # desktop brightness flicker some panels show with VRR always on.
      variable-refresh-rate = "on-demand";
      focus-at-startup = true;
    };
    "DP-2" = {
      mode = {
        width = 2560;
        height = 1440;
        refresh = 74.924;
      };
      scale = 1.0;
      position = {
        x = 2560;
        y = 0;
      };
    };
  };
}
