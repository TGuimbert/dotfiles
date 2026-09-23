{ ... }:
{
  hardware.facter.reportPath = ./facter.json;

  # The PC611 stops answering if APST lets it reach its deepest sleep state, and
  # the failure conceals itself: /var/log is on that drive, so the controller
  # timeout never reaches the journal. What it looks like instead is the journal
  # stopping mid-line with no error, every service that touches disk failing
  # (postgresql, mariadb, every sqlite one, lldap — so authelia then reports
  # "incorrect username or password" for a bind it cannot make), and everything
  # already resident in memory — traefik, authelia itself — serving happily for
  # hours afterwards. sshd accepts the connection and resets at kex, because the
  # listener is fine and only the new session needs disk. SMART is clean
  # afterwards and btrfs only reports a tree-log replay, so nothing on the next
  # boot points at the drive; the tell is the NVMe temperature disappearing from
  # beszel at the moment it happens.
  #
  # After the fact the test is `find /var/log /persistent /nix -xdev -newermt
  # <stall> ! -newermt <reboot>`, which returns *nothing* — six hours in which
  # traefik, gatus and beszel were all answering and not one byte reached the
  # disk. That is also what separates this from fork exhaustion, which presents
  # almost identically from outside: journald is already resident and needs no
  # fork to append, so under that failure these files would carry mtimes.
  #
  # The drive is not worn — 0 media errors, 100% spare, 1% used, nothing in its
  # error log — so this is firmware behaviour and not degradation. What it does
  # expose is a non-operational PS4 at 4mW whose entry+exit latency totals
  # 10000us, well inside the 100000us the kernel tolerates by default, so APST
  # is free to park it there whenever the host goes idle. Hence intervals of 3h
  # to 26h, which is why this reads as random rather than as a power state.
  #
  # 0 disables the deep states entirely rather than capping the tolerance just
  # under PS4 (anything from 2000 to 9999 would keep PS3): idle watts are not
  # worth a drive that stops answering on a host with no console. LVFS carries
  # no newer firmware than 11000111 as of 2026-09.
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
