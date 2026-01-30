{ pkgs, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    actionlint
    ansible
    ansible-lint
    restic
    tenv
    terraform-ls
    tofu-ls
  ];

  shellHook = ''
    if [[ -e .terraform-version ]]; then
      tenv tf install --quiet
    fi
  '';
}
