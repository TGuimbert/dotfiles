# noctalia-greeter: the login screen, on greetd. Replaces GDM.
#
# Appearance is declarative here rather than pushed from the running shell
# (noctalia's Sync Now, `shell.greeter_sync`): that path stages files into
# /var/lib/noctalia-greeter through pkexec, which the tmpfs root wipes every boot
# and whose polkit action asks for the admin password each time. The cost is one
# fixed wallpaper instead of the shell's rotation.
{ inputs, ... }:
{
  nixos.modules.desktop =
    {
      appearance,
      lib,
      ...
    }:
    let
      # Destructured because the greeter's own settings block is also called
      # `appearance`, and reading the module arg from inside it looks like a
      # shadow even though attrset keys are not in scope.
      inherit (appearance) font cursor wallpaper;

      # Same vendored Gruvbox Material palette the shell uses (./noctalia.nix).
      palette = (builtins.fromJSON (builtins.readFile ./gruvbox-material-palette.json)).dark;

      # noctalia names its entries mPrimary / mOnSurfaceVariant; the greeter's
      # [appearance.palette] wants primary / on_surface_variant. Convert rather
      # than re-typing sixteen hex values that would then drift.
      # "mOnSurfaceVariant" -> [ "m" ["On"] "" ["Surface"] "" ["Variant"] "" ] -> "on_surface_variant"
      greeterKey =
        name:
        builtins.split "([A-Z][a-z]*)" name
        |> builtins.filter builtins.isList
        |> map (group: lib.toLower (builtins.head group))
        |> lib.concatStringsSep "_";

      # The keys the greeter documents. noctalia's palette carries three more
      # (surface_dim, on_surface_dim, outline_variant) that it has no slot for.
      greeterPaletteKeys = [
        "primary"
        "on_primary"
        "secondary"
        "on_secondary"
        "tertiary"
        "on_tertiary"
        "error"
        "on_error"
        "surface"
        "on_surface"
        "surface_variant"
        "on_surface_variant"
        "outline"
        "shadow"
        "hover"
        "on_hover"
      ];
    in
    {
      imports = [ inputs.noctalia-greeter.nixosModules.default ];

      programs.noctalia-greeter = {
        # Pulls in greetd, which creates the `greeter` user, takes tty1 from getty,
        # orders itself after plymouth and unlocks the keyring at login.
        enable = true;

        settings = {
          # `Name=` from niri's wayland-sessions entry — the picker label, not the
          # .desktop id. List them with `noctalia-greeter sessions`.
          session.default = "Niri";
          user.default = "tguimbert";

          appearance = {
            # "Synced" = use the palette below rather than a builtin scheme.
            scheme = "Synced";
            theme_mode = "dark";
            font_family = font.name;

            palette =
              palette
              # drops the nested `terminal` table
              |> lib.filterAttrs (_: value: builtins.isString value)
              |> lib.mapAttrs' (name: value: lib.nameValuePair (greeterKey name) value)
              |> lib.filterAttrs (name: _: builtins.elem name greeterPaletteKeys);

            # The same image the session opens on (./appearance.nix, which also
            # seeds noctalia's wallpaper folder with it). A store path, readable
            # by the unprivileged greeter user.
            wallpaper = {
              path = "${wallpaper}";
              fill_mode = "crop";
            };
          };

          # greetd starts greeters with an empty environment, so XCURSOR_* never
          # reaches the compositor: name the theme here, with a search path since
          # it is not under the default icon dirs.
          cursor = {
            theme = cursor.name;
            inherit (cursor) size;
            path = "${cursor.package}/share/icons";
          };

          # Mirrors modules/locale.nix so the password field types the same as the
          # session: us(intl) primary, fr(oss) AZERTY on Scroll Lock.
          keyboard = {
            layout = "us,fr";
            variant = "intl,oss";
            options = "grp:sclk_toggle";
          };

          # Blank the outputs after 5 min at the login screen (off by default).
          idle.timeout = 300;
        };
      };
    };
}
