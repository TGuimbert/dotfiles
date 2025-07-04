{ pkgs, channels, ... }:
pkgs.mkShell {
  packages = with channels.unstable; [
    uv
    fnm
    # Language Server Protocol
    python313Packages.python-lsp-server
    ruff
    python313Packages.pylsp-mypy
  ];
  shellHook = with pkgs; ''
    export LD_LIBRARY_PATH="${
      lib.makeLibraryPath [
      ]
    }:$LD_LIBRARY_PATH"
    export GDAL_LIBRARY_PATH="${lib.makeLibraryPath [ pkgs.gdal ]}/libgdal.so"
    export "GEOS_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.geos ]}/libgeos_c.so"
    export UV_LINK_MODE=copy
    eval "$(fnm env)"
  '';
}
