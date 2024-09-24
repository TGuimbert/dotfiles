{ ... }:
{
  programs = {
    zellij = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        default_shell = "fish";
        ui = {
          pane_frames = {
            rounded_corners = true;
          };
        };
      };
    };
  };
  home.sessionVariables = {
    ZELLIJ_AUTO_ATTACH = "true";
    ZELLIJ_AUTO_EXIT = "true";
  };
}
