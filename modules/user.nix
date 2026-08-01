{ ... }:
{
  # The single owner of the account; ./users.nix only wires home-manager.
  nixos.modules.base =
    { pkgs, ... }:
    {
      users = {
        mutableUsers = false;
        users.tguimbert = {
          name = "tguimbert";
          description = "Thibault Guimbert";
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          uid = 1000;
          # Over ssh the login shell *is* the shell environment, so it has to be
          # the one ./nushell.nix configures. bash stays available as a fallback
          # (`ssh <host> -t bash -l`).
          shell = pkgs.nushell;
          openssh.authorizedKeys.keys = [
            "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIA8ELMPZWIVpqfdLifNdzuMMEDdZFzqRKuExaFISizYrAAAAC3NzaDpob21lbGFi ssh:homelab"
          ];
        };
      };

      environment.shells = [ pkgs.nushell ];

      security.sudo.extraConfig = "Defaults lecture=\"never\"";
    };

  nixos.modules.desktop.users.users.tguimbert = {
    extraGroups = [ "networkmanager" ];
    hashedPasswordFile = "/persistent/tguimbert-password";
  };
}
