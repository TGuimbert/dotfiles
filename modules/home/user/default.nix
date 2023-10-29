{ ... }:
let
  username = "tguimbert";
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
}

