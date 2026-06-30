{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.aiven-client = pkgs.python3Packages.buildPythonApplication rec {
        pname = "aiven-client";
        version = "4.12.0";
        pyproject = true;

        src = pkgs.fetchFromGitHub {
          owner = "aiven";
          repo = "aiven-client";
          rev = version;
          hash = "sha256-0kGCbt08HOawwkHKxK76QfaDno+70iKs+zhTxOE+7hA=";
        };

        build-system = with pkgs.python3Packages; [
          hatchling
          hatch-vcs
        ];

        dependencies = with pkgs.python3Packages; [
          requests
          requests-toolbelt
          certifi
        ];

        env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

        doCheck = false;

        meta = {
          description = "Aiven command-line client";
          homepage = "https://github.com/aiven/aiven-client";
          license = pkgs.lib.licenses.asl20;
          mainProgram = "avn";
        };
      };
    };
}
