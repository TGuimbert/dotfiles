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
    interfaces.lan0.ipv4.addresses = [
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
