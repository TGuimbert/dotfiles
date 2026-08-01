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
        restic
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

  homeManager.modules.base =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        jq
        dig
      ];

      programs = {
        bat.enable = true;
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
