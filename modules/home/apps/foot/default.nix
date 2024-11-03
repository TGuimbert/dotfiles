{ ... }:
{
  programs.foot = {
    enable = true;
    server.enable = true;
    settings = {
      main = {
        shell = "nu -c 'zellij -l welcome'";
        initial-window-mode = "maximized";
      };
    };
  };
}
