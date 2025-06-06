{ pkgs, channels, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    python310
    channels.unstable.uv
    ruff
    pre-commit
    python312Packages.python-lsp-server
    python312Packages.pip
    # Postgis libraries
    gdal
    geos
    # TOML lsp
    taplo
    # Other libraries
    zlib
    glib
    libglvnd
    file
  ];
  shellHook = with pkgs; ''
    # uv has to use copy mode because hardlinks do not work with impermanence
    export UV_LINK_MODE=copy
    uv venv --link-mode copy --allow-existing --quiet
    source .venv/bin/activate
    # Postgis libraries
    export "GDAL_LIBRARY_PATH=${gdal}/lib/libgdal.so"
    export "GEOS_LIBRARY_PATH=${geos}/lib/libgeos_c.so"
    # Other libraries
    export LD_LIBRARY_PATH="${zlib}/lib:${glib.out}/lib:${libglvnd}/lib:${pkgs.stdenv.cc.cc.lib}/lib:${gfortran.cc.lib}/lib:${file}/lib"
    # Skip ruff in pre-commit
    export "SKIP=ruff,ruff-format"
  '';
}
