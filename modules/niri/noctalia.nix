# noctalia (native Wayland shell for niri: bar / launcher / notifications /
# lockscreen) plus the in-session theming it renders for foot, helix, zellij,
# starship, bat, Claude Code, Firefox (pywalfox) and Obsidian. Merges into the
# same home-manager `niri` aspect as ./niri.nix (both are deferredModules, so the
# values combine), so importing the `niri` aspect pulls this in too.
{ inputs, ... }:
{
  homeManager.modules.niri =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      # Palette placeholder that resolves to the active light/dark mode. Shared by
      # the starship + Claude Code templates below (both map noctalia's palette
      # onto their own color slots with the exact same `.default` mode ref).
      activeColor = name: "{{colors.${name}.default.hex}}";

      # Vendored Gruvbox Material palette (dark + light + terminal colors) — the
      # source for noctalia's custom palette (bar + the app-theme templates below).
      gruvboxMaterial = builtins.fromJSON (builtins.readFile ./gruvbox-material-palette.json);

      # foot has no live config reload, so recolor a *running* terminal with OSC
      # escape sequences instead. noctalia renders this template (substituting the
      # {{colors.terminal_*}} placeholders) to ~/.cache/terminal-sequences and the
      # post_hook tees it to every PTY. printf emits the raw ESC/BEL bytes at build
      # time; the {{…}} placeholders pass through untouched for noctalia to fill.
      terminalSequences = pkgs.runCommand "noctalia-terminal-sequences.tmpl" { } ''
        {
          printf '\033]10;{{colors.terminal_foreground.default.hex}}\007'
          printf '\033]11;{{colors.terminal_background.default.hex}}\007'
          printf '\033]12;{{colors.terminal_cursor.default.hex}}\007'
          printf '\033]17;{{colors.terminal_selection_bg.default.hex}}\007'
          printf '\033]19;{{colors.terminal_selection_fg.default.hex}}\007'
          printf '\033]4;0;{{colors.terminal_normal_black.default.hex}}\007'
          printf '\033]4;1;{{colors.terminal_normal_red.default.hex}}\007'
          printf '\033]4;2;{{colors.terminal_normal_green.default.hex}}\007'
          printf '\033]4;3;{{colors.terminal_normal_yellow.default.hex}}\007'
          printf '\033]4;4;{{colors.terminal_normal_blue.default.hex}}\007'
          printf '\033]4;5;{{colors.terminal_normal_magenta.default.hex}}\007'
          printf '\033]4;6;{{colors.terminal_normal_cyan.default.hex}}\007'
          printf '\033]4;7;{{colors.terminal_normal_white.default.hex}}\007'
          printf '\033]4;8;{{colors.terminal_bright_black.default.hex}}\007'
          printf '\033]4;9;{{colors.terminal_bright_red.default.hex}}\007'
          printf '\033]4;10;{{colors.terminal_bright_green.default.hex}}\007'
          printf '\033]4;11;{{colors.terminal_bright_yellow.default.hex}}\007'
          printf '\033]4;12;{{colors.terminal_bright_blue.default.hex}}\007'
          printf '\033]4;13;{{colors.terminal_bright_magenta.default.hex}}\007'
          printf '\033]4;14;{{colors.terminal_bright_cyan.default.hex}}\007'
          printf '\033]4;15;{{colors.terminal_bright_white.default.hex}}\007'
        } > $out
      '';

      # zellij theme — one template emits BOTH `noctalia-dark` and
      # `noctalia-light` blocks (explicit .dark/.light color refs, so the file is
      # mode-independent and loads at startup). zellij can't hot-reload theme
      # files, so the template's post_hook flips the *active* theme per session
      # via the CLI action, deterministically from the {{ mode }} placeholder.
      mkZellijTheme =
        mode:
        let
          c = f: "{{colors.${f}.${mode}.hex}}";
          comp = n: bg: base: ''
            ${n} {
              background "${c bg}"
              base "${c base}"
              emphasis_0 "${c "primary"}"
              emphasis_1 "${c "secondary"}"
              emphasis_2 "${c "tertiary"}"
              emphasis_3 "${c "error"}"
            }'';
        in
        lib.concatStringsSep "\n" [
          (comp "text_unselected" "surface" "on_surface")
          (comp "text_selected" "surface_variant" "on_surface")
          (comp "ribbon_unselected" "surface_variant" "on_surface_variant")
          (comp "ribbon_selected" "primary" "on_primary")
          (comp "table_title" "surface" "primary")
          (comp "table_cell_unselected" "surface" "on_surface")
          (comp "table_cell_selected" "surface_variant" "on_surface")
          (comp "list_unselected" "surface" "on_surface")
          (comp "list_selected" "surface_variant" "on_surface")
          (comp "frame_selected" "surface" "primary")
          (comp "frame_highlight" "surface" "secondary")
          ''
            exit_code_error {
              background "${c "surface"}"
              base "${c "terminal_normal_red"}"
              emphasis_0 "${c "primary"}"
              emphasis_1 "${c "secondary"}"
              emphasis_2 "${c "tertiary"}"
              emphasis_3 "${c "error"}"
            }''
          ''
            exit_code_success {
              background "${c "surface"}"
              base "${c "terminal_normal_green"}"
              emphasis_0 "${c "primary"}"
              emphasis_1 "${c "secondary"}"
              emphasis_2 "${c "tertiary"}"
              emphasis_3 "${c "error"}"
            }''
          ''
            multiplayer_user_colors {
              player_1 "${c "primary"}"
              player_2 "${c "secondary"}"
              player_3 "${c "tertiary"}"
              player_4 "${c "terminal_normal_yellow"}"
              player_5 "${c "terminal_normal_magenta"}"
              player_6 "${c "terminal_normal_cyan"}"
              player_7 "${c "terminal_normal_red"}"
              player_8 "${c "terminal_normal_green"}"
              player_9 "${c "terminal_bright_blue"}"
              player_10 "${c "outline"}"
            }''
        ];

      zellijThemeTemplate = pkgs.writeText "noctalia-zellij.kdl.tmpl" ''
        themes {
          noctalia-dark {
        ${mkZellijTheme "dark"}
          }
          noctalia-light {
        ${mkZellijTheme "light"}
          }
        }
      '';

      # starship: same template mechanism as foot/helix/zellij. The base prompt
      # (format + modules) comes from modules/starship.nix via
      # config.programs.starship.settings; only the palette block is swapped for
      # {{colors.*.default.hex}} placeholders. `.default` resolves to the active
      # light/dark mode, so the prompt follows mode switches. Names mirror the old
      # static palette: orange→secondary, base01→surface_variant,
      # bright-*→terminal_bright_*. noctalia renders this to the mutable cache file
      # STARSHIP_CONFIG points at (the HM-managed ~/.config/starship.toml stays a
      # read-only symlink noctalia can't write). No reload hook is needed: starship
      # re-reads its config on every prompt, so the next prompt is already
      # recolored after a palette/mode change.
      starshipTemplate = (pkgs.formats.toml { }).generate "starship-noctalia.toml.tmpl" (
        config.programs.starship.settings
        // {
          palette = "noctalia";
          palettes.noctalia = {
            orange = activeColor "secondary";
            base01 = activeColor "surface_variant";
            "bright-black" = activeColor "terminal_bright_black";
            "bright-blue" = activeColor "terminal_bright_blue";
            "bright-cyan" = activeColor "terminal_bright_cyan";
            "bright-yellow" = activeColor "terminal_bright_yellow";
            "bright-white" = activeColor "terminal_bright_white";
          };
        }
      );

      # Claude Code custom theme: a JSON `{ name, base, overrides }`. `base =
      # {{ mode }}` inherits the active light/dark built-in for the slots we don't
      # override; overrides map noctalia's palette onto Claude Code's color slots.
      claudeTheme = (pkgs.formats.json { }).generate "noctalia-claude-theme.json" {
        name = "Noctalia";
        base = "{{ mode }}";
        overrides = {
          claude = activeColor "primary";
          text = activeColor "on_surface";
          secondaryText = activeColor "on_surface_variant";
          suggestion = activeColor "terminal_normal_blue";
          success = activeColor "terminal_normal_green";
          error = activeColor "terminal_normal_red";
          warning = activeColor "terminal_normal_yellow";
          permission = activeColor "terminal_normal_blue";
          planMode = activeColor "terminal_normal_cyan";
          autoAccept = activeColor "terminal_normal_magenta";
        };
      };

      # Vendored + wrapped copy of noctalia's community obsidian apply.sh (so
      # nothing is fetched at runtime and find/python3 resolve from the store).
      # `output` emits the per-vault snippet paths; `apply` enables the snippet in
      # each vault's appearance.json.
      obsidianApply = pkgs.writeShellScriptBin "noctalia-obsidian-apply" ''
                export PATH=${
                  lib.makeBinPath (
                    with pkgs;
                    [
                      coreutils
                      findutils
                      python3
                    ]
                  )
                }:$PATH
                set -euo pipefail

                snippet_name="noctalia"

                find_vaults() {
                  find "$HOME" -maxdepth 4 -name ".obsidian" -type d 2>/dev/null | sort -u
                }

                case "''${1:-}" in
                  output)
                    find_vaults | while read -r obsidian_dir; do
                      snippets_dir="$obsidian_dir/snippets"
                      mkdir -p "$snippets_dir"
                      echo "$snippets_dir/$snippet_name.css"
                    done
                    ;;
                  apply)
                    find_vaults | while read -r obsidian_dir; do
                      appearance_file="$obsidian_dir/appearance.json"
                      if [ ! -f "$appearance_file" ]; then
                        printf '{\n  "enabledCssSnippets": ["%s"]\n}\n' "$snippet_name" > "$appearance_file"
                        continue
                      fi
                      python3 -c "
        import json
        with open('$appearance_file') as f:
            data = json.load(f)
        snippets = data.get('enabledCssSnippets', [])
        if '$snippet_name' not in snippets:
            snippets.append('$snippet_name')
            data['enabledCssSnippets'] = snippets
            with open('$appearance_file', 'w') as f:
                json.dump(data, f, indent=2)
                f.write('\n')
        " 2>/dev/null || true
                    done
                    ;;
                  *)
                    echo "Usage: noctalia-obsidian-apply {output|apply}" >&2
                    exit 1
                    ;;
                esac
      '';
    in
    {
      imports = [ inputs.noctalia.homeModules.default ];

      # noctalia is the in-session theme authority for the apps it templates
      # (foot, helix, zellij, niri, starship, bat, …). stylix stays the base for
      # everything else — fonts, cursor, console, GTK/QT, the GNOME session — as a
      # fixed gruvbox-dark.
      #
      # Guard: when stylix ships its own `stylix.targets.noctalia` (present on
      # stylix master; absent from our release-26.05, expected ~26.11) it will
      # auto-drive noctalia's palette and clash with the manual theme below. This
      # assertion blocks the build so we reconcile deliberately — either set
      # `stylix.targets.noctalia.enable = false` to keep this, or adopt the target.
      assertions = [
        {
          assertion = !(options.stylix.targets ? noctalia);
          message = ''
            stylix now ships `stylix.targets.noctalia`, which will drive
            noctalia's theme and conflict with the manual palette/templates in
            modules/niri/noctalia.nix. Either set `stylix.targets.noctalia.enable
            = false` to keep this config, or drop the manual theme and adopt the
            target.
          '';
        }
      ];

      # stylix target hand-offs — noctalia owns the palette for the apps it
      # templates; disabling stylix's targets for them avoids fighting over the
      # same colors. stylix keeps theming every other app.
      stylix.targets = {
        # foot/helix/zellij/niri: theming handed to noctalia's side-file templates
        # (rendered below); the links/includes make each app pick them up.
        foot.enable = false;
        helix.enable = false;
        zellij.enable = false;
        niri.enable = false;

        # bat + starship: mkForce because stylix.nix enables these targets
        # explicitly (unlike foot/helix). noctalia renders their palettes live so
        # they follow the auto day/night mode instead of stylix's fixed variant.
        bat.enable = lib.mkForce false;
        starship.enable = lib.mkForce false;

        # Import noctalia's rendered gtk css (see the gtk3/gtk4 builtin_ids below).
        # Declared via stylix's extraCss so apply.sh finds it present and won't
        # rewrite the read-only gtk.css symlink.
        gtk.extraCss = ''@import url("noctalia.css");'';
      };

      # Seed noctalia's wallpaper folder with the stylix image. Drop more images
      # into this dir (another xdg.configFile entry) and noctalia will offer them.
      xdg.configFile."noctalia/wallpapers/gruvbox-stairs.jpg".source = config.stylix.image;

      # Install the pywalfox native-messaging manifest (noctalia is the pywalfox
      # host; the Pywalfox extension is added in modules/desktop/firefox.nix).
      # Letting the binary emit it keeps the manifest from drifting from the pinned
      # noctalia input; re-running on every activation self-heals it after each
      # tmpfs-root boot wipes ~/.mozilla (so no preservation entry needed), and
      # install() only writes when absent/noctalia-owned, so it's safe to repeat.
      home.activation.noctaliaFirefoxHost = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${config.programs.noctalia.package}/bin/noctalia firefox-theme install
      '';

      programs = {
        # Point each app at noctalia's rendered side theme file. Declaring the link
        # here (instead of letting noctalia's apply.sh edit the read-only HM config)
        # keeps it declarative — foot's apply.sh sees the include already present
        # and skips its own edit; helix has no hook and just loads the named theme.
        foot.settings.main.include = "~/.config/foot/themes/noctalia";
        helix.settings.theme = "noctalia";

        # zellij: noctalia writes both theme blocks to themes/noctalia.kdl; select
        # them as the dark/light themes and the template post_hook flips the active
        # one live. `theme` is forced off the shared module's "stylix".
        zellij.settings = {
          theme = lib.mkForce "noctalia-dark";
          theme_dark = "noctalia-dark";
          theme_light = "noctalia-light";
        };

        # starship: STARSHIP_CONFIG points at the noctalia-rendered cache file (see
        # starshipTemplate above) so the prompt follows the live light/dark mode.
        # The HM-managed ~/.config/starship.toml symlink is left unused (read-only,
        # so noctalia can't write it in place).
        nushell.environmentVariables.STARSHIP_CONFIG = "${config.home.homeDirectory}/.cache/starship.toml";

        # bat: select the noctalia theme rendered by the user template below.
        # Selecting via HM's option (a declarative `--theme=noctalia` in bat's
        # config) applies to every shell, not just nushell — and HM legitimately
        # owns that config file, so this isn't the in-place apply.sh rewrite we
        # avoid. bat is spawned fresh per invocation, so it picks up each cache
        # rebuild with no reload.
        bat.config.theme = "noctalia";

        # Claude Code: select the noctalia custom theme rendered by the user
        # template below. Set here (niri aspect) rather than in
        # modules/claude/claude.nix so it only applies on hosts that actually run
        # noctalia to render the theme file; merges into the settings from
        # claude.nix. "custom:<slug>" is Claude Code's selector for
        # $CLAUDE_CONFIG_DIR/themes/<slug>.json.
        claude-code.settings.theme = "custom:noctalia";

        noctalia = {
          enable = true;

          settings = {
            theme = {
              # Gruvbox Material, generated from base16-schemes (dark + light
              # variants below). noctalia has no builtin for it. mkDefault so a
              # future stylix.targets.noctalia can override cleanly; the assertion
              # above still forces a conscious decision when that lands.
              #
              # auto = follow day/night from location (auto_locate below). Only the
              # noctalia-owned surfaces (bar, foot, helix) switch; stylix's apps are
              # baked dark and won't follow — an accepted split until user-space
              # theming moves fully to noctalia.
              mode = lib.mkDefault "auto";
              source = "custom";
              custom_palette = "gruvbox-material";

              # Render side theme files from the palette; the links/includes above
              # make each app pick them up. Everything else stays stylix.
              templates = {
                enable_builtin_templates = true;
                builtin_ids = [
                  "foot"
                  "helix"
                  "niri"
                  # GTK colors only — GTK apps (Nautilus, file-picker dialogs) follow
                  # the live day/night palette. stylix keeps the base theme/cursor/font
                  # (targets.gtk stays on); the `@import` is declared via
                  # stylix.targets.gtk.extraCss above so apply.sh finds it present and
                  # won't rewrite the read-only gtk.css symlink. (electron apps ignore
                  # GTK for their inner UI.)
                  "gtk3"
                  "gtk4"
                ];
                # Each template's render logic + reasoning is on its `let` binding
                # above; comments here note only per-app render hooks.
                user = {
                  terminal-sequences = {
                    enabled = true;
                    input_path = "${terminalSequences}";
                    output_path = "~/.cache/terminal-sequences";
                    post_hook = "${pkgs.coreutils}/bin/tee /dev/pts/[0-9]* < ~/.cache/terminal-sequences";
                  };
                  # post_hook flips the active theme per running session (zellij can't
                  # hot-reload theme files); covers colors_changed too.
                  zellij-theme = {
                    enabled = true;
                    input_path = "${zellijThemeTemplate}";
                    output_path = "~/.config/zellij/themes/noctalia.kdl";
                    post_hook = ''${pkgs.zellij}/bin/zellij list-sessions -sn 2>/dev/null | while read -r s; do ${pkgs.zellij}/bin/zellij -s "$s" action set-{{ mode }}-theme; done'';
                  };
                  starship = {
                    enabled = true;
                    input_path = "${starshipTemplate}";
                    output_path = "~/.cache/starship.toml";
                  };
                  # post_hook rebuilds bat's cache (bat re-reads it each run); the
                  # cache is on tmpfs so a fresh boot self-heals after noctalia starts.
                  bat = {
                    enabled = true;
                    input_path = "${./bat-noctalia.tmTheme}";
                    output_path = "~/.config/bat/themes/noctalia.tmTheme";
                    post_hook = "${pkgs.bat}/bin/bat cache --build";
                  };
                  # No post_hook — Claude Code watches its themes dir and hot-reloads.
                  claude-code = {
                    enabled = true;
                    input_path = "${claudeTheme}";
                    output_path = "~/.config/claude/themes/noctalia.json";
                  };
                  # Vendored community `pywalfox-beta4` template so it renders offline.
                  # post_action "firefox-theme" pushes the rendered colors.json to the
                  # Pywalfox extension via the noctalia native-messaging host installed
                  # by the noctaliaFirefoxHost activation above.
                  firefox = {
                    enabled = true;
                    input_path = "${./pywalfox-colors.json.tmpl}";
                    output_path = "~/.cache/wal/colors.json";
                    post_action = "firefox-theme";
                  };
                  # obsidianApply (above) discovers each vault and enables the snippet.
                  # NB: the snippet is written *inside the vault*, so anything syncing
                  # .obsidian (Obsidian Sync / Syncthing / git) propagates these colors
                  # to other instances — exclude snippets/noctalia.css to keep it local.
                  obsidian = {
                    enabled = true;
                    input_path = "${./obsidian-noctalia.css.tmpl}";
                    output_path_dynamic = "${obsidianApply}/bin/noctalia-obsidian-apply output";
                    post_hook = "${obsidianApply}/bin/noctalia-obsidian-apply apply";
                  };
                };
              };
            };
            # helix re-reads its theme on SIGUSR1. Gotchas: the hook key is
            # `colors_changed` (plural — `color_changed` is silently ignored); no
            # `-x` because nixpkgs' `hx` is a makeWrapper stub (`comm` = `.hx-wrapped`).
            hooks = {
              theme_mode_changed = "${pkgs.procps}/bin/pkill -USR1 hx";
              colors_changed = "${pkgs.procps}/bin/pkill -USR1 hx";
            };

            shell = {
              # nerd font for the bar's glyphs/icons
              font_family = lib.mkDefault "IosevkaTerm Nerd Font";
            };

            # External-monitor brightness over DDC/CI (gated off by default in
            # noctalia). Enabling it makes noctalia manage VCP 0x10 per monitor;
            # requires ddcutil + i2c access, wired in ./niri.nix's nixos aspect.
            brightness.enable_ddcutil = true;

            weather.enabled = true;
            # auto_locate resolves location from the public IP at runtime, so none is
            # committed to this public repo. Also feeds nightlight's schedule.
            location.auto_locate = true;

            # Night light — warms color temperature after sunset (independent of the
            # theme.mode="auto" palette swap). Schedule is derived from
            # location.auto_locate above; temperature_day must stay above _night.
            nightlight = {
              enabled = true;
              temperature_day = 6500;
              temperature_night = 4000;
            };

            wallpaper = {
              # A folder so more can be added later; seeded with the stylix image
              # via xdg.configFile above.
              directory = "${config.xdg.configHome}/noctalia/wallpapers";

              # Rotate randomly (off by default; interval_seconds keeps its 30-min
              # default). Recursive so subdirectories are eligible too.
              automation = {
                enabled = true;
                order = "random";
                recursive = true;
              };
            };

            # Idle handling — niri has none of its own; noctalia's idle manager owns
            # it. Staggered: lock, then screen-off, then suspend. Toggle the whole set
            # at runtime with the caffeine idle-inhibitor.
            idle = {
              # Fade a fullscreen dim overlay in over this many seconds before the
              # action fires; any input during the fade cancels it. 0 = no overlay.
              pre_action_fade_seconds = 2.0;

              # hyphenated keys must be quoted in Nix.
              behavior = {
                lock = {
                  enabled = true;
                  timeout = 600; # 10 min → lock the session
                  action = "lock";
                };
                "screen-off" = {
                  enabled = true;
                  timeout = 660; # 11 min → DPMS the monitors off (wakes on input)
                  action = "screen_off";
                };
                "lock-and-suspend" = {
                  enabled = true;
                  timeout = 1800; # 30 min → lock, then systemctl suspend
                  action = "lock_and_suspend";
                };
              };
            };
          };

          # Gruvbox Material, vendored as JSON so it's not fetched at runtime.
          customPalettes.gruvbox-material = gruvboxMaterial;
        };
      };
    };
}
