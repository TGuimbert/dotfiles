{ ... }:
{
  # Baseline merge point for headless server hosts (srv-01), imported by the
  # machine the same way desktop hosts import `desktop`. Only what is genuinely
  # headless belongs here; the rest is in `base`.
  nixos.modules.server =
    { config, ... }:
    {
      sops = {
        defaultSopsFile = ../../secrets/srv-01.yaml;
        secrets.hashed-password.neededForUsers = true;
      };

      users.users.tguimbert.hashedPasswordFile = config.sops.secrets.hashed-password.path;

      services = {
        xserver.enable = false;
        pipewire.enable = false;
      };

      networking = {
        networkmanager.enable = false;
        # Servers declare a static address in their own _hosts/<host>/hardware.nix.
        useDHCP = false;
        firewall = {
          enable = true;
        };
      };
    };
}
