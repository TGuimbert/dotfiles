{ inputs, ... }:
{
  nixos.modules.base = {
    imports = [ inputs.sops-nix.nixosModules.sops ];
  };

  nixos.modules.desktop = {
    sops = {
      defaultSopsFile = ../secrets/common.yaml;
      # Read the host key from the persistent subvolume (neededForBoot, so
      # mounted before activation) rather than /etc/ssh/ssh_host_ed25519_key:
      # under preservation that symlink is only created by tmpfiles in stage-2,
      # after sops' setupSecrets has already run in the initrd activation.
      age.sshKeyPaths = [ "/persistent/etc/ssh/ssh_host_ed25519_key" ];
    };
  };
}
