{ config, ... }:
{
  homeManager.modules.gui.imports = [ config.homeManager.modules.gh ];

  homeManager.modules.gh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.gh = {
        enable = true;
        gitCredentialHelper.enable = false;
        settings = {
          git_protocol = "ssh";
          editor = lib.mkIf config.programs.helix.enable (lib.mkDefault "hx");
          aliases = {
            pc = "pr create --assignee @me";
            co = "pr checkout";
            pv = "pr view";
            pw = "pr view --web";
            pcw = "pr checks --web";
          };
        };
        extensions = with pkgs; [
          gh-dash
          gh-eco
          gh-markdown-preview
        ];
      };

    };

  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.files = [
    ".config/gh/hosts.yml"
  ];
}
