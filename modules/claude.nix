{ ... }:
{
  homeManager.modules.gui =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      claude-statusline = pkgs.writeShellApplication {
        name = "claude-statusline";
        runtimeInputs = [ pkgs.jq ];
        text = builtins.readFile ../config/claude/statusline.sh;
      };
    in
    {
      programs.claude-code = {
        enable = true;
        configDir = "${config.xdg.configHome}/claude";
        marketplaces.karpathy-skills = pkgs.fetchFromGitHub {
          owner = "forrestchang";
          repo = "andrej-karpathy-skills";
          rev = "2c606141936f1eeef17fa3043a72095b4765b9c2";
          hash = "sha256-4z/wRdYH7UXRzF8RJU0sw8xbpx0BW/7CBv5sVEC2knY=";
        };
        settings = {
          model = "opus";
          statusLine = {
            type = "command";
            command = lib.getExe claude-statusline;
          };
          includeCoAuthoredBy = false;
          enabledPlugins."andrej-karpathy-skills@karpathy-skills" = true;
          env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        };
      };

      home.persistence."/persistent".directories = [
        ".config/claude"
        ".local/share/claude-code"
      ];
    };
}
