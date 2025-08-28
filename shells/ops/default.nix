{ pkgs, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    actionlint
    ansible
    ansible-language-server
    restic
    tenv
    terraform-ls
  ];

  shellHook = ''
    if [[ -e .terraform-version ]]; then
      tenv tf install --quiet
    fi
  '';
}
