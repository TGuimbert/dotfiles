{ ... }:
{
  homeManager.modules.gui = {
    programs.k9s.enable = true;

    xdg.configFile = {
      "k9s/plugins.yaml".source = ./plugins.yaml;
      "k9s/views.yaml".source = ./views.yaml;
    };
  };
}
