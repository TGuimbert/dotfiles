{ inputs, ... }:
{
  # Provides the `preservation.preserveAt` options to every host (srv-01
  # included). Preservation is NixOS-only, so per-user state is declared at the
  # system level via `preserveAt.<path>.users.tguimbert` in each feature file.
  nixos.modules.base = {
    imports = [ inputs.preservation.nixosModules.preservation ];
  };

  nixos.modules.desktop = {
    preservation = {
      enable = true;
      preserveAt."/persistent" = {
        commonMountOptions = [ "x-gvfs-hide" ];
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
          {
            file = "/etc/machine-id";
            inInitrd = true;
          }
          # host keys are symlinked so preservation never rewrites their 0600
          # mode (a bindmount would apply the default 0644 and break sshd)
          {
            file = "/etc/ssh/ssh_host_rsa_key";
            how = "symlink";
            configureParent = true;
          }
          {
            file = "/etc/ssh/ssh_host_ed25519_key";
            how = "symlink";
            configureParent = true;
          }
          "/etc/ssh/ssh_host_rsa_key.pub"
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];
      };
    };

    # machine-id is bind-mounted from the initrd; the commit service is not
    # relevant in this setup for a persistent machine-id.
    systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

    # Preservation creates intermediate parents of user paths *up to but not
    # including* the home directory, and user bind-mounts run at sysinit before
    # NixOS creates the home. Create the volatile home dir here so those mounts
    # have a target.
    systemd.tmpfiles.settings.preservation."/home/tguimbert".d = {
      user = "tguimbert";
      group = "users";
      mode = "0700";
    };
  };
}
