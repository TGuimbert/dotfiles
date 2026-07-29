# Pin a power-profiles-daemon profile at boot. Generic opt-in aspect: any host
# that imports `powerProfiles` gets power-profiles-daemon enabled, and can pin a
# boot-time default by setting `custom.defaultPowerProfile`. Needed because on
# the tmpfs-root hosts the daemon's last selection (persisted under /var/lib) is
# wiped every boot, so it otherwise always comes up `balanced`. Leaving the
# option null just runs the daemon at its own default (no oneshot).
{ ... }:
{
  nixos.modules.powerProfiles =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      profile = config.custom.defaultPowerProfile;
    in
    {
      options.custom.defaultPowerProfile = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "performance"
            "balanced"
            "power-saver"
          ]
        );
        default = null;
        example = "power-saver";
        description = ''
          power-profiles-daemon profile to pin once at boot. null leaves the
          daemon at its own default (balanced). Flip it live afterwards from a
          power widget or `powerprofilesctl set`.
        '';
      };

      config = {
        services.power-profiles-daemon.enable = true;

        systemd.services.default-power-profile = lib.mkIf (profile != null) {
          description = "Default to the ${profile} profile at boot";
          after = [ "power-profiles-daemon.service" ];
          wants = [ "power-profiles-daemon.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set ${profile}";
          };
        };
      };
    };
}
