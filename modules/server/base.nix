{ ... }:
{
  # Baseline merge point for headless server hosts (srv-01). Imported by the
  # machine the same way desktop hosts import `desktop`.
  nixos.modules.server =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      boot.loader = {
        # mkDefault so the `secureBoot` aspect can hand the ESP to lanzaboote.
        # Plain systemd-boot is what the machine installs on, before the sbctl
        # keys exist; see README.
        systemd-boot.enable = lib.mkDefault true;
        efi.canTouchEfiVariables = true;
      };

      nix.settings = {
        trusted-users = [
          "root"
          "tguimbert"
        ];
        experimental-features = [
          "nix-command"
          "flakes"
        ];
      };

      sops = {
        defaultSopsFile = ../../secrets/srv-01.yaml;
        age.sshKeyPaths = [ "/persistent/etc/ssh/ssh_host_ed25519_key" ];
        secrets.hashed-password.neededForUsers = true;
      };

      services = {
        openssh = {
          enable = true;
          hostKeys = [
            {
              path = "/etc/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
          ];
          settings = {
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };
        };
        xserver.enable = false;
        pipewire.enable = false;
        # Real disk now, not a virtio block device.
        smartd.enable = true;
      };

      environment.systemPackages = with pkgs; [
        htop
        iotop
        zellij
        helix
        curl
        wget
        git
      ];

      networking = {
        networkmanager.enable = false;
        # The address is declared per host (see machines/srv-01.nix); a server
        # that moves address on a DHCP whim is a server you cannot find.
        useDHCP = false;
        firewall = {
          enable = true;
        };
      };

      users = {
        mutableUsers = false;
        users.tguimbert = {
          isNormalUser = true;
          hashedPasswordFile = config.sops.secrets.hashed-password.path;
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [
            "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIA8ELMPZWIVpqfdLifNdzuMMEDdZFzqRKuExaFISizYrAAAAC3NzaDpob21lbGFi ssh:homelab"
          ];
        };
      };

      preservation = {
        enable = true;
        preserveAt."/persistent" = {
          commonMountOptions = [ "x-gvfs-hide" ];
          directories = [
            "/var/lib/nixos"
            "/var/lib/systemd/coredump"
          ];
          files = [
            {
              file = "/etc/machine-id";
              inInitrd = true;
            }
            {
              file = "/etc/ssh/ssh_host_ed25519_key";
              how = "symlink";
              configureParent = true;
            }
            "/etc/ssh/ssh_host_ed25519_key.pub"
          ];
        };
      };

      systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

      # tmpfs root needs no wipe service; initrd systemd kept for the inInitrd
      # machine-id.
      boot.initrd.systemd.enable = true;
    };
}
