{ pkgs, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    ansible
    ansible-language-server
    tenv
    terraform-ls
    restic
  ];
}
