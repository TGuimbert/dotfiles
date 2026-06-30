{ config, inputs, ... }:
{
  nixos.configurations.leshen = {
    module = {
      imports =
        (with config.nixos.modules; [
          base
          desktop
        ])
        ++ [
          inputs.disko.nixosModules.disko

          # leshen-specific legacy modules (move to machines/ + named aspects later).
          ../../hosts/leshen/hardware.nix
          ../../hosts/leshen/disks.nix
          ../_nixos/games.nix
          ../_nixos/podman.nix
        ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # Legacy home packages/persistence still live in ./home; desktop GUI config
      # (gnome/stylix/firefox) now arrives via homeManager.modules.gui (the `desktop` aspect).
      home-manager.users.tguimbert.imports = [ ../../home ];

      system.stateVersion = "22.11";
    };
  };
}
