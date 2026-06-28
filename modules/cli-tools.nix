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
    };

  homeManager.modules.gui = {
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
      k9s.enable = true;
    };

    xdg.configFile = {
      "k9s/plugins.yaml".source = ../config/k9s/plugins.yaml;
      "k9s/views.yaml".source = ../config/k9s/views.yaml;
    };
  };
}
