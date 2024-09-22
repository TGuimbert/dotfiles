{ ... }:
{
  programs = {
    zellij = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        default_shell = "fish";
      };
    };
  };
  home.sessionVariables = {
    ZELLIJ_AUTO_ATTACH = "true";
    ZELLIJ_AUTO_EXIT = "true";
  };
}
