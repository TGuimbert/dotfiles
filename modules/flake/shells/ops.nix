{ ... }:
{
  perSystem = { pkgs, ... }: {
    devShells.ops = pkgs.mkShell {
      packages = with pkgs; [
        actionlint
        aiven-client
        ansible
        ansible-lint
        openssl
        postgresql
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
    };
  };
}
