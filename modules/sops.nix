{ inputs, ... }:
{
  nixos.modules.base = {
    imports = [ inputs.sops-nix.nixosModules.sops ];
  };

  nixos.modules.desktop = {
    sops = {
      defaultSopsFile = ../secrets/common.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
  };
}
