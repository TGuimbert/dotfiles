{ config, ... }:
{
  nixos.modules.base = { pkgs, ... }: {
    # iotop uses Linux kernel interfaces; portable tools belong to the home.
    environment.systemPackages = [ pkgs.iotop ];
    preservation.preserveAt."/persistent".users.tguimbert.directories = [
      ".local/share/zoxide"
      ".cache/tealdeer"
    ];
  };

  nixos.modules.desktop = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.restic ];
  };

  homeManager.modules = {
    base.imports = [ config.homeManager.modules.cliTools ];

    cliTools = { pkgs, ... }: {
      imports = with config.homeManager.modules; [
        bat
        eza
        zoxide
      ];
      home.packages = with pkgs; [
        fd
        procs
        sd
        dust
        ripgrep
        bottom
        htop
        wget
        jq
        dig
      ];
    };

    bat = { lib, ... }: {
      programs.bat = {
        enable = true;
        # Noctalia overrides this only in the Linux desktop composition.
        config.theme = lib.mkDefault "ansi";
      };
    };

    eza = {
      programs.eza = {
        enable = true;
        git = true;
        icons = "auto";
        extraOptions = [
          "--group-directories-first"
          "--header"
        ];
      };
    };

    zoxide.programs.zoxide.enable = true;

    gui = { pkgs, ... }: {
      # dprint is owned by helixLanguages alongside its other formatters.
      home.packages = with pkgs; [
        asciinema
        fastfetch
      ];
    };
  };

}
