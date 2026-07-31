{ config, inputs, ... }:
{
  nixos.configurations.leshen = {
    module = {
      imports =
        (with config.nixos.modules; [
          base
          desktop
          secureBoot
          podman
          games
          displaysLeshen
        ])
        ++ [
          inputs.disko.nixosModules.disko

          ../_hosts/leshen/hardware.nix
          ../_hosts/leshen/disks.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # Boot into the power-saver profile (leshen-specific; the generic mechanism
      # lives in modules/power-profiles.nix). On leshen the profiles are backed by
      # amd_pstate EPP (no ACPI platform_profile), so this just lowers the CPU
      # energy/performance bias — flip it live any time from noctalia's power
      # widget or `powerprofilesctl set`.
      custom.defaultPowerProfile = "power-saver";

      system.stateVersion = "22.11";
    };
  };
}
