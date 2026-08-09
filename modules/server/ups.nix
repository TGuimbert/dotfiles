{ ... }:
{
  # A NUT secondary, and nothing else. The UPS is on the TrueNAS's USB port and
  # the NAS runs `upsd` as the primary, so this host holds no driver and opens no
  # port: it learns about the power from the machine that can see it. Same split
  # as ./beszel.nix, for the same reason.
  #
  # What it does with that: shuts srv-01 down **ten minutes into any outage**
  # rather than riding the battery down. The rest of the runtime is worth more to
  # the NAS, which is where the bytes are, and going first also gets this host off
  # the NFS export in ./media-library.nix before the server holding it disappears
  # — a `hard` mount whose server is gone hangs the unmount.
  #
  # Two things it cannot do, both in ../../CLAUDE.md: bring itself back up, since
  # the outlet is never de-energized; and notice an outage at all when the NAS is
  # what died rather than the mains.
  nixos.modules.ups =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      onBattSeconds = 600;

      # upssched's socket and lock. Not /run/nut, which the module's ExecStartPre
      # creates root-owned.
      runtimeDir = "/run/upssched";
      trigger = "${runtimeDir}/early-shutdown";

      # upsmon forks: the root parent exists only to run SHUTDOWNCMD, and the
      # monitoring child drops to `nutmon` before it execs NOTIFYCMD. So upssched
      # and this script are unprivileged, and NUT's own idiom — `upsmon -c fsd` —
      # fails with EPERM against a root-owned pid. Dropping a marker for a path
      # unit to watch is cheaper than a polkit rule, and much cheaper than running
      # the whole of upsmon as root.
      cmdScript = pkgs.writeShellScript "upssched-cmd" ''
        case "$1" in
          earlyshutdown) ${lib.getExe' pkgs.coreutils "touch"} ${trigger} ;;
        esac
      '';
    in
    {
      sops.secrets.upsMonitorPassword = { };

      power.ups = {
        enable = true;
        mode = "netclient";

        upsmon = {
          monitor.nas = {
            # The address and not `nas.lan` as ../_hosts/_lib/nfs.nix uses: this
            # is the one client that has to keep working while the LAN is losing
            # power, and the router answering DNS may not be on the UPS. `ups` is
            # the identifier TrueNAS defaults to.
            system = "ups@10.0.0.55";
            user = "srv-01";

            # Stated rather than defaulted: the option falls back to
            # `power.ups.users.<user>.passwordFile`, and that attrset generates
            # upsd.users — the primary's file, which this host does not have.
            passwordFile = config.sops.secrets.upsMonitorPassword.path;

            # Not the module's "master" default: the NAS grants this account
            # `upsmon secondary`, so claiming primary logs "Primary privileges
            # unavailable" on every poll and buys nothing.
            type = "secondary";
          };

          # Only the two events the timer keys off gain EXEC; the rest keep
          # upsmon's SYSLOG default, which is the whole of the alerting here.
          # NOTIFYCMD is already upssched.
          settings.NOTIFYFLAG = [
            [
              "ONBATT"
              "SYSLOG+EXEC"
            ]
            [
              "ONLINE"
              "SYSLOG+EXEC"
            ]
          ];
        };

        # The early shutdown only. The low-battery path underneath it needs no
        # rule: LOWBATT, or an FSD declared by the NAS, runs SHUTDOWNCMD at once
        # whatever the timer is doing. PIPEFN has to precede the ATs, or upssched
        # refuses to parse this at all.
        schedulerRules = "${pkgs.writeText "upssched.conf" ''
          CMDSCRIPT ${cmdScript}
          PIPEFN ${runtimeDir}/upssched.pipe
          LOCKFN ${runtimeDir}/upssched.lock

          AT ONBATT * START-TIMER earlyshutdown ${toString onBattSeconds}
          AT ONLINE * CANCEL-TIMER earlyshutdown
        ''}";
      };

      systemd = {
        # upssched creates its socket and lock here, as nutmon.
        tmpfiles.settings.ups.${runtimeDir}.d = {
          user = "nutmon";
          group = "nutmon";
          mode = "0700";
        };

        # The privileged half of cmdScript above. Starting the target is what
        # `systemctl poweroff` does anyway, so no service sits in between — which
        # also avoids a oneshot unit asking for a transaction that stops itself.
        paths.ups-early-shutdown = {
          description = "Power off ${toString (onBattSeconds / 60)} minutes into an outage";
          wantedBy = [ "multi-user.target" ];
          pathConfig = {
            PathExists = trigger;
            Unit = "poweroff.target";
          };
        };
      };
    };
}
