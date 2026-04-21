{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.bottom = inputs.nix-wrapper-modules.wrappers.bottom.wrap { inherit pkgs; };
    };

  flake.nixosModules.cli-tools =
    { pkgs, lib, config, inputs, ... }:
    {
      options.features.shell.cli-tools.enable = lib.mkEnableOption "CLI tools" // {
        default = true;
      };

      config = lib.mkIf config.features.shell.cli-tools.enable {
        environment.systemPackages =
          (with pkgs; [
            fd
            procs
            sd
            dust
            ripgrep
            bitwarden-cli
            fastfetch
          ])
          ++ [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.bottom ];

        home-manager.users.tguimbert = {
          programs = {
            eza = {
              enable = true;
              git = true;
              icons = "auto";
              extraOptions = [
                "--group-directories-first"
                "--header"
              ];
            };
            zoxide.enable = true;
            k9s.enable = true;
          };

          xdg.configFile = {
            "k9s/plugins.yaml".source = ../../../config/k9s/plugins.yaml;
            "k9s/views.yaml".source = ../../../config/k9s/views.yaml;
          };
        };
      };
    };
}
