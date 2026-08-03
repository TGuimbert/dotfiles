{ inputs, ... }:
{
  # Provides the `preservation.preserveAt` options to every host (srv-01
  # included). Preservation is NixOS-only, so per-user state is declared at the
  # system level via `preserveAt.<path>.users.tguimbert` in each feature file.
  nixos.modules.base = {
    imports = [ inputs.preservation.nixosModules.preservation ];

    preservation = {
      enable = true;
      preserveAt."/persistent" = {
        commonMountOptions = [ "x-gvfs-hide" ];
        directories = [
          {
            directory = "/tmp";
            mode = "1777";
          }
          "/var/lib/systemd/timers"
          # inInitrd because this holds the uid-map that pins every
          # dynamically-allocated system user, and NixOS allocates those in the
          # stage-2 activation script — before systemd, so before an ordinary
          # bind-mount exists. Read too late, the map looks empty, every system
          # user is renumbered, and services stop being able to read their own
          # 0600 state. /etc/passwd is on the tmpfs root and so cannot stand in:
          # it is regenerated every boot, leaving no incumbent uid to preserve.
          # Prescribed by preservation's own docs.
          #
          # This covers reboots. Across a *rebuild* there is no map either — the
          # backup in server/backup.nix stages a copy whose ownership is
          # flattened outright — so services owning preserved state additionally
          # pin their ids in their own aspect
          # (server/{traefik,lldap,authelia,calibre}.nix). Those values are read
          # back from `getent passwd` rather than chosen, so they cannot collide.
          # Pinning them is also what makes a restore's chown deterministic.
          {
            directory = "/var/lib/nixos";
            inInitrd = true;
          }
          "/var/lib/systemd/coredump"
          "/var/lib/fwupd"
        ];
        files = [
          {
            file = "/var/lib/systemd/random-seed";
            how = "symlink";
            inInitrd = true;
            configureParent = true;
          }
          {
            file = "/etc/machine-id";
            inInitrd = true;
          }
          # The host key is symlinked so preservation never rewrites its 0600
          # mode (a bindmount would apply the default 0644 and break sshd).
          # ed25519 only — see services.openssh in ./services.nix.
          {
            file = "/etc/ssh/ssh_host_ed25519_key";
            how = "symlink";
            configureParent = true;
          }
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

  nixos.modules.desktop.preservation.preserveAt."/persistent".directories = [
    "/var/lib/bluetooth"
    "/var/lib/boltd"
    "/var/lib/tailscale"
    "/etc/NetworkManager/system-connections"
    "/var/lib/systemd/rfkill"
    "/var/lib/power-profiles-daemon"
  ];
}
