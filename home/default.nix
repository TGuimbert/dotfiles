{ ... }:
{
  # Steam / games home persistence. Everything else from this file moved into
  # capability-co-located dendritic aspects in R12; this remainder is migrated to
  # modules/steam.nix in R13, after which this file is deleted. Imported only by
  # the games hosts (leshen, griffin).
  home.persistence."/persistent".directories = [
    ".local/share/Steam"
    ".steam"
    ".clonehero"
    ".config/unity3d/srylain Inc_/Clone Hero"
  ];
}
