{ ... }:
{
  # Baseline merge point for headless server hosts (srv-01). Imported by the
  # machine the same way desktop hosts import `desktop`.
  nixos.modules.server =
    {
      pkgs,
      config,
      ...
    }:
    {
      boot.loader.grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
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
        qemuGuest.enable = true;
        xserver.enable = false;
        pipewire.enable = false;
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
        useDHCP = true;
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
