{
  description = "nix-darwin consuming dotfiles terminal modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dotfiles.url = "github:TGuimbert/dotfiles";
  };

  outputs =
    {
      nix-darwin,
      home-manager,
      dotfiles,
      ...
    }:
    {
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        modules = [
          home-manager.darwinModules.home-manager
          ({ pkgs, ... }: {
            nixpkgs.hostPlatform = "aarch64-darwin"; # Use x86_64-darwin for Intel.
            # Optional: use the repo's Helix, Nushell/plugins and Carapace versions.
            nixpkgs.overlays = [ dotfiles.overlays.terminal ];

            # Replace this example account with your existing macOS username.
            system.primaryUser = "alice";
            users.users.alice.home = "/Users/alice";
            system.stateVersion = 6;

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.alice = {
                imports = [
                  dotfiles.homeModules.terminalSuite
                  # Optional LSPs and formatters, independent of any GUI:
                  # dotfiles.homeModules.helixLanguages
                  # Personal GPG/YubiKey configuration and signed commits:
                  # dotfiles.homeModules.gpg
                ];
                home.stateVersion = "26.05";
                programs.git.settings.user = {
                  name = "Alice";
                  email = "alice@example.com";
                };
              };
            };

            # Launch `nu` from your terminal. Registering it here also makes it
            # available for an explicit login-shell change by the account owner.
            environment.shells = [ pkgs.nushell ];
          })
        ];
      };
    };
}
