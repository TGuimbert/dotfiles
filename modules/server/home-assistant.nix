{ inputs, ... }:
let
  # `vmAddress` is a DHCP reservation for `macAddress` on the router rather than
  # static config inside the guest: dnsmasq then registers the name, and a
  # reseeded guest lands on the right address untouched — HAOS keeps its network
  # settings in the OS layer, which an HA backup does not restore. Keep the
  # address out of the dynamic pool.
  vmAddress = "10.0.0.52";
  macAddress = "02:81:fd:53:ce:51";

  diskImage = "/var/lib/libvirt/images/haos.qcow2";
in
{
  # Home Assistant OS as a libvirt guest. HAOS rather than nixpkgs'
  # `services.home-assistant` because only a full HAOS install carries the
  # supervisor, and only the supervisor can restore the backups from the Proxmox
  # instance this replaces.
  nixos.modules.homeAssistant =
    {
      constants,
      pkgs,
      mkRouter,
      ...
    }:
    let
      nixvirt = inputs.nixvirt.lib;

      base = nixvirt.domain.templates.linux {
        name = "haos";
        uuid = "987480bd-0c79-458d-9310-bec4804b6f74";
        vcpu.count = 2;
        memory = {
          count = 4;
          unit = "GiB";
        };
        storage_vol = diskImage;
        # Defined in ../_hosts/srv-01/hardware.nix, which explains why it exists.
        bridge_name = "br0";
        net_iface_mac = macAddress;
        # A virtio model with accel3d would want a GL-backed display; this guest
        # only ever gets looked at over VNC, so take the qxl model instead.
        virtio_video = false;
      };

      domain = base // {
        os = base.os // {
          # Nothing to boot off the empty cdrom the template also adds.
          boot = [ { dev = "hd"; } ];
          # HAOS x86-64 boots UEFI only, and wants a firmware built without
          # secure boot — `pkgs.OVMF` is exactly that (`OVMFFull` carries the SB
          # variants). libvirt copies the VARS template into the nvram path on
          # first start, which is why /var/lib/libvirt is preserved below.
          loader = {
            readonly = true;
            type = "pflash";
            path = pkgs.OVMF.fd.firmware;
          };
          nvram = {
            template = pkgs.OVMF.fd.variables;
            path = "/var/lib/libvirt/qemu/nvram/haos_VARS.fd";
          };
        };

        devices = base.devices // {
          # The template reaches for full `qemu`, ~570 MB of which is emulators
          # for architectures this host will never run.
          emulator = "${pkgs.qemu_kvm}/bin/qemu-system-x86_64";

          # 10c4:ea60 — the SkyConnect Zigbee radio — in *decimal*, because Nix
          # has no hex literals and NixVirt renders ints with toString. Re-derive
          # after a dongle swap with `printf '%d %d\n' 0x10c4 0xea60`; libvirt
          # normalises them back, so `virsh dumpxml haos` is the check.
          hostdev = [
            {
              mode = "subsystem";
              type = "usb";
              managed = true;
              source = {
                # Without this the guest refuses to start whenever the dongle is
                # absent, a poor trade for a house's automation. The flip side is
                # that libvirt won't hot-add it either: a dongle plugged in after
                # the guest booted needs a restart to be picked up.
                startupPolicy = "optional";
                vendor.id = 4292;
                product.id = 60000;
              };
            }
          ];

          # The template targets a SPICE desktop; a headless server wants a
          # console it can reach over SSH instead. `virsh console haos` for the
          # serial one, or tunnel 5900 for the framebuffer.
          graphics = {
            type = "vnc";
            port = 5900;
            autoport = false;
            listen = {
              type = "address";
              address = "127.0.0.1";
            };
          };
          serial = {
            type = "pty";
          };
          console = {
            type = "pty";
            target.type = "serial";
          };
          sound = null;
          audio = null;
          redirdev = null;
          # Keep the qemu guest agent (libvirt shuts the guest down through it),
          # drop the spicevmc channel that went with SPICE.
          channel = [
            {
              type = "unix";
              target = {
                type = "virtio";
                name = "org.qemu.guest_agent.0";
              };
            }
          ];
        };
      };
    in
    {
      imports = [ inputs.nixvirt.nixosModules.default ];

      homepageTiles.Services = [
        {
          HomeAssistant = {
            icon = "home-assistant.png";
            href = "https://homeassistant.${constants.domain}/";
            siteMonitor = "https://homeassistant.${constants.domain}/";
            description = "Home automation";
          };
        }
      ];

      virtualisation = {
        libvirt = {
          enable = true;
          # NixVirt would otherwise reach into its own nixpkgs for libvirt.
          package = pkgs.libvirt;
          connections."qemu:///system".domains = [
            {
              definition = nixvirt.domain.writeXML domain;
              active = true;
              # Never restart the guest on activation. `autoUpgrade` rebuilds
              # this host nightly at 03:00, and a definition diff — a bumped OVMF
              # store path, say — would otherwise take the heating and the lights
              # down with it. Definition changes land in the persistent config
              # and apply at the next deliberate restart.
              restart = false;
            }
          ];
        };
        libvirtd = {
          # Match the emulator picked above; libvirtd otherwise stages the full
          # qemu into /run/libvirt/nix-emulators and onto the system path.
          qemu.package = pkgs.qemu_kvm;
          # Default is "suspend", which restores a guest with a stale clock and a
          # stale view of its Zigbee dongle. ACPI shutdown instead, so the
          # nightly kernel reboot stops HAOS cleanly.
          onShutdown = "shutdown";
        };
      };

      # Seeds a fresh HAOS install once and then leaves it alone — HAOS updates
      # itself in place, so this pin only ever matters for a bare-metal rebuild
      # of srv-01. It costs ~550 MB of store space to keep that reproducible.
      systemd.services.haos-image =
        let
          # The `ova` artifact, *not* `generic-x86-64`: the generic one is the
          # bare-metal image, and HAOS detects it running under virtualization
          # and marks the install unsupported (`virtualization_image`). The OVA
          # image is the KVM one — para-virt drivers and guest tools included.
          image = pkgs.fetchurl {
            url = "https://github.com/home-assistant/operating-system/releases/download/18.2/haos_ova-18.2.qcow2.xz";
            hash = "sha256-JU5T81TfBznjr8Cb5UMaB99T8N9rcDiFQE9mXEVPJU4=";
          };
        in
        {
          description = "Seed the Home Assistant OS disk image";
          requiredBy = [ "nixvirt.service" ];
          before = [ "nixvirt.service" ];
          unitConfig.ConditionPathExists = "!${diskImage}";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [ pkgs.xz ];
          # Written under a temporary name so an interrupted seed cannot leave a
          # half-written image that the condition above would then treat as done.
          # No resize: the artifact is already a qcow2 with a 32 GB virtual size,
          # which HAOS grows its data partition into on first boot.
          script = ''
            mkdir -p "$(dirname ${diskImage})"
            xz -dc ${image} > ${diskImage}.tmp
            chmod 0600 ${diskImage}.tmp
            mv ${diskImage}.tmp ${diskImage}
          '';
        };

      preservation.preserveAt."/persistent".directories = [ "/var/lib/libvirt" ];

      # Deliberately not `mkAutheliaRouter`: Home Assistant authenticates its own
      # users, and a forward-auth in front of it breaks the companion app,
      # webhooks and every long-lived-token API client — none of which can follow
      # an interactive SSO redirect. Traefik is here for TLS and one certificate
      # story, not for authentication.
      #
      # HA rejects proxied requests unless it is told to trust this hop, so the
      # guest's configuration.yaml needs:
      #     http:
      #       use_x_forwarded_for: true
      #       trusted_proxies: [ 10.0.0.57 ]
      services.traefik.dynamicConfigOptions.http = mkRouter {
        name = "homeassistant";
        url = "http://${vmAddress}:8123";
      };
    };
}
