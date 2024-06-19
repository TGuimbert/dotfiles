{ pkgs, channels, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    python310
    channels.unstable.uv
    ruff
    pre-commit
    # Postgis libraries
    gdal
    geos
  ];
  shellHook = ''
    uv venv --link-mode copy --allow-existing --quiet
    source .venv/bin/activate
    # Postgis libraries
    export "GDAL_LIBRARY_PATH=${pkgs.gdal}/lib/libgdal.so"
    export "GEOS_LIBRARY_PATH=${pkgs.geos}/lib/libgeos_c.so"
    # Skip ruff in pre-commit
    export "SKIP=ruff,ruff-format"
  '';
}
