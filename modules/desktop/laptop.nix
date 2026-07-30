# Laptop-only session bits. Opt-in aspect (`laptop`), imported from
# modules/machines/griffin.nix. Kept out of `desktop` because logind is
# system-wide and leshen has no lid to hand over.
{ config, ... }:
{
  nixos.modules.laptop = {
    home-manager.users.tguimbert.imports = [ config.homeManager.modules.laptop ];

    # Hands the lid to the compositor so it can lock *before* suspending (the
    # switch-events bind below) instead of racing logind and resuming unlocked.
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
    };

    # systemd-backlight restores the panel brightness from here at boot; on the
    # tmpfs root it is wiped, so the panel otherwise comes up at the firmware
    # default every time.
    preservation.preserveAt."/persistent".directories = [ "/var/lib/systemd/backlight" ];
  };

  # Needs the logind hand-off above, or logind suspends first and the session
  # resumes unlocked. Switch binds accept nothing but spawn actions.
  homeManager.modules.laptop.programs.niri.settings.switch-events.lid-close.action.spawn = [
    "noctalia"
    "msg"
    "session"
    "lock-and-suspend"
  ];
}
