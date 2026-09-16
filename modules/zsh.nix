{ ... }: {
  homeManager.modules.zsh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs = {
        zsh = {
          enable = true;
          enableCompletion = true;
          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;
          history.path = "${config.xdg.dataHome}/zsh/history";
          shellAliases = import ./_lib/shell-aliases.nix { inherit config lib pkgs; };
        };

        carapace.enable = true;
      };
    };
}
