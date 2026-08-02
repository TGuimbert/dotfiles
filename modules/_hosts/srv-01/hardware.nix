{ ... }:
{
  hardware.facter.reportPath = ./facter.json;

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
