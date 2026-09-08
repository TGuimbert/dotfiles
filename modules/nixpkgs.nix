{ inputs, ... }:
let
  # Optional portable package policy for consumers of homeModules. Keep the
  # Nushell executable and its plugins from the same nixpkgs revision.
  terminalOverlay =
    _final: prev:
    # Unstable has dropped Intel macOS; retain the consumer's stable packages.
    if prev.stdenv.hostPlatform.system == "x86_64-darwin" then
      { }
    else
      let
        unstable = import inputs.unstable {
          system = prev.stdenv.hostPlatform.system;
        };
      in
      {
        inherit (unstable)
          helix
          nushell
          nushellPlugins
          carapace
          ;
      };

  overlay =
    final: prev:
    let
      unstable = import inputs.unstable {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    in
    (terminalOverlay final prev)
    // {
      inherit (unstable)
        k9s
        obsidian
        orca-slicer
        rustfinity
        calibre
        sone
        claude-code
        ;

      # The one override here that is not a "newer is nicer" desktop package, and
      # so the only one with an expiry: 26.05 carries 0.22.3, whose `auth.forwarded`
      # upstream removed in 0.23 in favour of the `auth.oidc` ./server/readeck.nix
      # configures. Only the package is overridden; that file explains why pairing
      # it with 26.05's module is safe. A warning and not an assertion, because
      # failing eval would block the very lockfile PR that carries the fix.
      readeck =
        prev.lib.warnIf (prev.lib.versionAtLeast prev.readeck.version "0.23")
          "nixpkgs now carries readeck ${prev.readeck.version}; drop this override and modules/server/readeck.nix's note about it"
          unstable.readeck;

      azure-cli = unstable.azure-cli.withExtensions [
        unstable.azure-cli.extensions.ssh
      ];

      # Fix missing GTK schema crash on file dialogs: https://github.com/NixOS/nixpkgs/issues/467783
      freecad = prev.symlinkJoin {
        name = "freecad-wrapped";
        paths = [ prev.freecad ];
        nativeBuildInputs = [ prev.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/FreeCAD \
            --prefix XDG_DATA_DIRS : "${prev.gtk3}/share/gsettings-schemas/${prev.gtk3.name}"
        '';
      };
    };

  nixpkgsSettings = {
    config.allowUnfree = true;
    overlays = [ overlay ];
  };
in
{
  flake.overlays.default = overlay;
  flake.overlays.terminal = terminalOverlay;

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs ({ inherit system; } // nixpkgsSettings);
    };

  nixos.modules.base = {
    nixpkgs = nixpkgsSettings;
  };
}
