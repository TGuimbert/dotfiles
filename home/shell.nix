{ ... }:
{
  imports = [
    ../modules/features/shell/terminal.nix
    ../modules/features/shell/helix.nix
    ../modules/features/shell/nushell.nix
    ../modules/features/shell/zellij.nix
    ../modules/features/shell/starship.nix
    ../modules/features/shell/cli-tools.nix
  ];
}
