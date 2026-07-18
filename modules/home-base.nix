{ ... }:
{
  # Generic home remainder: top-level data dirs that have no more specific owner.
  nixos.modules.desktop.preservation.preserveAt."/persistent".users.tguimbert.directories = [
    "Documents"
    "Downloads"
    "Music"
    "Pictures"
    "Videos"
    "Workspace"
    ".dotfiles"
  ];
}
