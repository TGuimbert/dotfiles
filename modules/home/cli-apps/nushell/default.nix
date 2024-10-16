{ ... }:
{
  programs = {
    nushell = {
      enable = true;
    };
    carapace = {
      enable = true;
    };
  };

  home.persistence."/persistent/home/tguimbert" = {
    files = [ ".config/nushell/history.txt" ];
  };
}
