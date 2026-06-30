{ ... }:
{
  perSystem = { pkgs, config, ... }: {
    devShells.ops = pkgs.mkShell {
      packages = [ config.packages.aiven-client ] ++ (with pkgs; [
        actionlint
        ansible
        ansible-lint
        openssl
        postgresql
        restic
        tenv
        terraform-ls
        tofu-ls
      ]);

      shellHook = ''
        if [[ -e .terraform-version ]]; then
          tenv tf install --quiet
        fi
      '';
    };
  };
}
