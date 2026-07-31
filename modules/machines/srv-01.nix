{ config, inputs, ... }:
{
  nixos.configurations.srv-01.module = {
    imports =
      (with config.nixos.modules; [
        base
        server
        secureBoot
        traefik
        authelia
        lldap
        homepage
        restic
        calibre
        printing
      ])
      ++ [
        inputs.disko.nixosModules.disko

        ../_hosts/srv-01/hardware.nix
        ../_hosts/srv-01/disks.nix
      ];

    nixpkgs.hostPlatform = "x86_64-linux";

    # The uplink is a USB 2.5G dongle, not the onboard NIC (enp2s0 has no cable).
    # Its predictable name encodes the USB port path — enp0s20f0u1 — so moving it
    # to another port renames the interface and takes the address with it. Match
    # the MAC and give it a name of our own. .link files are consumed by udev, so
    # this needs no networkd. If the cable ever moves to the onboard port, the MAC
    # here is what changes.
    systemd.network.links."10-lan" = {
      matchConfig.MACAddress = "cc:ba:bd:a8:46:85";
      linkConfig.Name = "lan0";
    };

    # facter detects both NICs and turns on per-interface DHCP, which would run
    # dhcpcd against the static address below — and against interface names that
    # no longer exist once the rename above applies. Same reason networking.nix
    # disables it on the desktops.
    hardware.facter.detected.dhcp.enable = false;

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

    system.stateVersion = "25.11";
  };
}
