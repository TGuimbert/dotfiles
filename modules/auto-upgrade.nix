{ ... }:
{
  # Pull-based updates, closing the loop the rest of the repo already sets up:
  # Renovate opens a lockfile PR → CI builds every host and pushes the closures
  # to tguimbert.cachix.org → automerge on green → the timer below pulls `main`
  # and substitutes what CI already built.
  nixos.modules.autoUpgrade = {
    system.autoUpgrade = {
      enable = true;
      # Public repo, so no credentials. The lockfile comes from the fetched
      # revision: this never runs `nix flake update` of its own accord.
      flake = "github:TGuimbert/dotfiles";
      # Nothing alerts on failure, so keep the build output in the journal for
      # `just upgrade-log` to show.
      flags = [ "--print-build-logs" ];

      # Early enough that even a from-source build lands inside the reboot window.
      dates = "03:00";
      randomizedDelaySec = "20min";

      # Only reboots when the built kernel/initrd differs from the booted one.
      # Unattended is safe here: LUKS is unlocked by the TPM against PCR 7, which
      # measures the Secure Boot keys, not the kernel.
      allowReboot = true;
      rebootWindow = {
        lower = "03:00";
        upper = "05:00";
      };
    };
  };
}
