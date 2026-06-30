{ ... }:
{
  # Generic home remainder: top-level data dirs that have no more specific owner.
  homeManager.modules.gui = {
    home.persistence."/persistent".directories = [
      "Documents"
      "Downloads"
      "Music"
      "Pictures"
      "Videos"
      "Workspace"
      ".dotfiles"
    ];
  };
}
