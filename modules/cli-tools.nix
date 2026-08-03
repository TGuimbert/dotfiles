{ ... }:
{
  nixos.modules.base =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        fd
        procs
        sd
        dust
        ripgrep
        bottom
        htop
        iotop
        wget
      ];

      preservation.preserveAt."/persistent".users.tguimbert.directories = [
        ".local/share/zoxide"
        ".cache/tealdeer"
      ];
    };

  nixos.modules.desktop =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.restic ];
    };

  homeManager.modules.base =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        jq
        dig
      ];

      programs = {
        bat = {
          enable = true;
          # The terminal's own colors off-desktop; ./desktop/noctalia.nix overrides.
          config.theme = "ansi";
        };
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
      };
    };

  # dprint is helix's markdown formatter, so it follows the language tooling in
  # ./helix.nix.
  homeManager.modules.gui =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        dprint
        asciinema
        fastfetch
      ];
    };
}
