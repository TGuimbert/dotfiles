# Secret storage. gnome-keyring itself is enabled by the niri module (it backs the
# Secret portal per niri-portals.conf) and unlocked at login by greetd's pam entry;
# its dbus packages also register gcr's SystemPrompter, which is what
# pinentry-gnome3 (modules/gpg.nix) draws its PIN dialog with.
{ ... }:
{
  nixos.modules.desktop = {
    # Defaults to gnome-keyring.enable, i.e. on. modules/ssh.nix runs its own
    # ssh-agent (SSH_AUTH_SOCK points at it, and its askpass is what prompts for
    # the yubikey PIN), so gcr's agent would be a second, unused agent racing for
    # the same job.
    services.gnome.gcr-ssh-agent.enable = false;

    # Free: modules/ssh.nix already puts seahorse in the closure for its askpass.
    programs.seahorse.enable = true;

    preservation.preserveAt."/persistent".users.tguimbert.directories = [
      ".local/share/keyrings"
    ];
  };
}
