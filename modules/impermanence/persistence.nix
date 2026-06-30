{ inputs, ... }:
{
  # Provides the `environment.persistence` / `home.persistence` options to every
  # host (srv-01 included). The home-manager option arrives via the module's
  # `home-manager.sharedModules`, which the base HM aspects rely on.
  nixos.modules.base = {
    imports = [ inputs.impermanence.nixosModules.impermanence ];
  };

  # Desktop hosts are wiped on reboot; persist the system state they need.
  nixos.modules.desktop = {
    environment.persistence."/persistent" = {
      hideMounts = true;
      directories = [
        "/var/lib/nixos"
        "/var/lib/fwupd"
        "/var/lib/systemd/coredump"
        "/var/lib/bluetooth"
        "/var/lib/boltd"
        "/var/lib/tailscale"
        "/etc/NetworkManager/system-connections"
        "/etc/secureboot"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
    };

    programs.fuse.userAllowOther = true;
  };
}
