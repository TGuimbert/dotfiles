{ ... }:
{
  nixos.modules.desktop =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        fd
        procs
        sd
        dust
        ripgrep
        bitwarden-cli
        fastfetch
        restic
        bottom
      ];

      preservation.preserveAt."/persistent".users.tguimbert.directories = [
        ".local/share/zoxide"
        ".cache/tealdeer"
      ];
    };

  homeManager.modules.gui =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        jq
        dig
        dprint
        asciinema
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
}
