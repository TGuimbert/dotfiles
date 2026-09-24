{ ... }:
{
  # Baseline merge point for headless server hosts (srv-01), imported by the
  # machine the same way desktop hosts import `desktop`. Only what is genuinely
  # headless belongs here; the rest is in `base`.
  nixos.modules.server =
    { config, pkgs, ... }:
    {
      # A headless host that wedges stays wedged until someone notices and walks
      # to it — srv-01 has done exactly that, hung with the power LED lit, no
      # disk activity, nothing on the wire and nothing in the journal, for six
      # hours and for ninety minutes. PID 1 pings /dev/watchdog every
      # runtimeTime/2 and the chip resets the board when the pings stop, so the
      # outage is a reboot instead of a morning. Mitigation and not a fix, which
      # is the point while the fault is still unidentified (see
      # ../_hosts/srv-01/hardware.nix).
      #
      # The board exposes two devices, intel_oc_wdt as watchdog0 and iTCO_wdt as
      # watchdog1; this takes systemd's default /dev/watchdog rather than pinning
      # one, since either resets the board and the numbering is not guaranteed
      # across kernels. 60s because PID 1 failing to run for a minute is already
      # pathological — if a nightly build ever trips it spuriously, raise this
      # rather than removing it. RebootWatchdogSec is left at its 10min default.
      systemd.settings.Manager.RuntimeWatchdogSec = "60s";

      # In the closure rather than reached for with `nix shell`: these are wanted
      # exactly when the disk or the network is the thing misbehaving, which is
      # when fetching a package does not work. memtester covers the allocatable
      # RAM online — the full memtest86+ pass needs a USB stick and Secure Boot
      # turned off in firmware, since lanzaboote owns the bootloader here and an
      # unsigned memtest image cannot be a boot entry.
      environment.systemPackages = with pkgs; [
        smartmontools
        nvme-cli
        memtester
      ];

      sops = {
        defaultSopsFile = ../../secrets/srv-01.yaml;
        secrets.hashed-password.neededForUsers = true;
      };

      users.users.tguimbert.hashedPasswordFile = config.sops.secrets.hashed-password.path;

      services = {
        xserver.enable = false;
        pipewire.enable = false;
      };

      networking = {
        networkmanager.enable = false;
        # Servers declare a static address in their own _hosts/<host>/hardware.nix.
        useDHCP = false;
        firewall = {
          enable = true;
        };
      };
    };
}
