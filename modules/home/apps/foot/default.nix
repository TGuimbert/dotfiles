{ ... }:
{
  programs.foot = {
    enable = true;
    server.enable = true;
    settings = {
      main = {
        shell = "fish -c 'zellij -l welcome'";
      };
    };
  };
}
