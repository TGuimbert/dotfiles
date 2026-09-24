{ ... }:
{
  hardware.facter.reportPath = ./facter.json;

  # Cheap insurance, not a fix: the host hung again 9h44m after this was
  # deployed, so whatever is wrong is not APST alone. What it does rule out is
  # the deepest sleep state — the PC611 exposes a non-operational PS4 at 4mW
  # whose entry+exit latency totals 10000us, well inside the 100000us the kernel
  # tolerates by default, so APST was free to park it there on every idle
  # period. 0 disables the non-operational states outright rather than capping
  # the tolerance just under PS4 (2000 to 9999 would keep PS3); idle watts are
  # not worth the risk on a host with no console, and the drive is measurably
  # healthy anyway — 0 media errors, 100% spare, 1% used, an empty controller
  # error log, all five btrfs counters at 0 and a clean scrub. LVFS carries no
  # firmware newer than 11000111 as of 2026-09.
  #
  # The fault itself is unidentified and predates this parameter. Its signature
  # is the journal stopping mid-line with every service healthy a second earlier
  # and *no* subsystem ever logging anything; the aftermath varies, from the
  # kernel surviving and serving from memory for six hours (2026-09-23) to a
  # total hang with the power LED lit and nothing on the wire (2026-09-24). The
  # memory is non-ECC (`EDAC ie31200: No ECC support`), so a memory fault here
  # cannot reach a log by construction — which is why ../../server/base.nix
  # carries a watchdog rather than this file carrying another workaround.
  #
  # Two things look diagnostic and are not, both costing an afternoon: `hrtimer:
  # interrupt took` appears in every boot including healthy ones, and
  # ippeveprinter precedes every failure only because a client polls it once a
  # minute. The one test that does discriminate is `find /var/log /persistent
  # /nix -xdev -newermt <stall> ! -newermt <reboot>` — returning nothing means
  # not one byte reached the disk while the host was still answering, which also
  # separates this from fork exhaustion, since journald is resident and needs no
  # fork to append.
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  # The uplink is a USB 2.5G dongle (onboard enp2s0 has no cable) and its
  # predictable name encodes the USB port path, so replugging it would strand the
  # address below. Pin by MAC instead — .link files are udev's, so no networkd.
  systemd.network.links."10-lan" = {
    matchConfig.MACAddress = "cc:ba:bd:a8:46:85";
    linkConfig.Name = "lan0";
  };

  networking = {
    # The host's address sits on a bridge rather than on lan0 directly so the
    # Home Assistant guest (see ../../server/home-assistant.nix) can be a peer on
    # the LAN: it needs L2 access for mDNS/SSDP discovery and for the inbound
    # callbacks half its integrations rely on, neither of which survives NAT.
    bridges.br0.interfaces = [ "lan0" ];
    interfaces.br0.ipv4.addresses = [
      {
        address = "10.0.0.57";
        prefixLength = 24;
      }
    ];
    defaultGateway = "10.0.0.1";
    nameservers = [
      "10.0.0.1"
      "fde3:f098:8f62::1"
    ];
    search = [ "lan" ];
  };
}
