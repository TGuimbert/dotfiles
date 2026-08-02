# noctalia (native Wayland shell for niri: bar / launcher / notifications /
# lockscreen) plus the in-session app theming it renders — the authority note on
# the home-manager aspect below lists what it owns. Merges into the same
# `desktop`/`gui` aspects as ./niri.nix (both are deferredModules, so the values
# combine).
{ inputs, ... }:
{
  # noctalia ships a NixOS module *and* a home-manager one; they share an option
  # name but nothing else. This half exists only for `recommendedServices`, which
  # enables the services the shell's widgets talk to (NetworkManager, bluetooth,
  # upower, power-profiles-daemon) — GNOME used to pull those in implicitly. All
  # mkDefault, so our own definitions still win.
  nixos.modules.desktop = {
    imports = [ inputs.noctalia.nixosModules.default ];

    programs.noctalia = {
      enable = true;
      # The home-manager module installs the shell into the user profile; leaving
      # this null keeps a single owner instead of also adding it system-wide.
      package = null;
      recommendedServices.enable = true;
      # noctalia deprecates systemd startup — niri's spawn-at-startup launches it.
      systemd.enable = false;
    };
  };

  homeManager.modules.gui =
    {
      appearance,
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # `.default` is noctalia's placeholder for whichever mode is active. Shared by
      # the starship + Claude Code templates below.
      activeColor = name: "{{colors.${name}.default.hex}}";

      # Vendored Gruvbox Material palette (dark + light + terminal colors) — the
      # source for noctalia's custom palette (bar + the app-theme templates below).
      gruvboxMaterial = builtins.fromJSON (builtins.readFile ./gruvbox-material-palette.json);

      # foot has no live config reload, so recolor a *running* terminal with OSC
      # escape sequences instead. noctalia renders this template (substituting the
      # {{colors.*}} placeholders) to ~/.cache/terminal-sequences and the
      # post_hook tees it to every PTY. printf emits the raw ESC/BEL bytes at build
      # time; the {{…}} placeholders pass through untouched for noctalia to fill.
      # This covers palette changes; a mode flip goes through foot's own theme switch
      # (the SIGUSR post_hook below).
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
          printf '\033]4;173;{{colors.secondary.default.hex}}\007'
          printf '\033]4;237;{{colors.surface_variant.default.hex}}\007'
        } > $out
      '';

      # Three consumers — noctalia renders it, foot includes it, activation places it
      # — and a mismatch between them costs foot its *entire* config, since a missing
      # include aborts the parse and takes the font and shell down with the colors.
      # Absolute, as the activation script needs.
      footThemeFile = "${config.xdg.configHome}/foot/themes/noctalia";

      # foot theme — replaces noctalia's builtin foot template, which emits a single
      # `[colors-dark]` section holding whatever mode was active at render time, so
      # foot's own dark/light switch had nothing to switch to. Emit both sections with
      # explicit .dark/.light refs (mode-independent, like the zellij theme below) and
      # let foot choose: `initial-color-theme` at startup, SIGUSR1/SIGUSR2 for a
      # running server (the post_hook). Keys mirror the upstream builtin template.
      # `color` resolves a noctalia color name to a bare RRGGBB value, which is
      # all foot.ini(5) accepts — from a placeholder for noctalia, or from the vendored
      # palette for the fallback below.
      mkFootColors =
        mode: color:
        let
          ansiNames = [
            "black"
            "red"
            "green"
            "yellow"
            "blue"
            "magenta"
            "cyan"
            "white"
          ];
        in
        lib.concatStringsSep "\n" (
          [
            "[colors-${mode}]"
            "foreground=${color "terminal_foreground"}"
            "background=${color "terminal_background"}"
          ]
          ++ lib.imap0 (i: name: "regular${toString i}=${color "terminal_normal_${name}"}") ansiNames
          ++ lib.imap0 (i: name: "bright${toString i}=${color "terminal_bright_${name}"}") ansiNames
          ++ [
            "selection-foreground=${color "terminal_selection_fg"}"
            "selection-background=${color "terminal_selection_bg"}"
            "cursor=${color "terminal_cursor_text"} ${color "terminal_cursor"}"
            # ../starship.nix needs an orange and a surface tone that ANSI 0-15 has no
            # room for, and a prompt rendered on srv-01 can only name palette slots.
            # Also in terminalSequences above, for terminals already running. Both
            # indices default to a near-identical xterm color, so a terminal without
            # this file still draws the prompt right.
            "173=${color "secondary"}"
            "237=${color "surface_variant"}"
          ]
        );

      mkFootTheme = initialTheme: color: ''
        [main]
        initial-color-theme=${initialTheme}
        ${mkFootColors "dark" (color "dark")}
        ${mkFootColors "light" (color "light")}
      '';

      footThemeTemplate = pkgs.writeText "noctalia-foot.tmpl" (
        mkFootTheme "{{ mode }}" (mode: name: "{{colors.${name}.${mode}.hex_stripped}}")
      );

      # The same file resolved from the vendored palette instead of placeholders,
      # because the foot server starts with graphical-session.target — a moment
      # *before* niri's noctalia has rendered anything. Not state: rebuilt from this
      # palette on every activation, which runs at boot, before the session. `dark` is
      # just the mode foot opens in until the first render signals the live one.
      footThemeFallback = pkgs.writeText "noctalia-foot-theme" (
        mkFootTheme "dark" (
          mode:
          let
            terminal = gruvboxMaterial.${mode}.terminal;
            byName = {
              terminal_foreground = terminal.foreground;
              terminal_background = terminal.background;
              terminal_cursor = terminal.cursor;
              terminal_cursor_text = terminal.cursorText;
              terminal_selection_fg = terminal.selectionFg;
              terminal_selection_bg = terminal.selectionBg;
              secondary = gruvboxMaterial.${mode}.mSecondary;
              surface_variant = gruvboxMaterial.${mode}.mSurfaceVariant;
            }
            // lib.concatMapAttrs (name: hex: { "terminal_normal_${name}" = hex; }) terminal.normal
            // lib.concatMapAttrs (name: hex: { "terminal_bright_${name}" = hex; }) terminal.bright;
          in
          name: lib.removePrefix "#" byName.${name}
        )
      );

      # zellij theme — one template emits three blocks: `noctalia-dark` and
      # `noctalia-light` (explicit .dark/.light refs, so the file is mode-independent
      # and loads at startup) plus `noctalia`, the active mode via `.default`. zellij
      # picks its theme from the read-only config.kdl, which can't follow the mode, so
      # `theme "noctalia"` gives a *newly started* session the live palette; the
      # -dark/-light pair backs the switch for sessions already running, which the
      # post_hook drives from the {{ mode }} placeholder (zellij can't hot-reload theme
      # files, and its own dark/light detection only reacts to a later flip).
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
          noctalia {
        ${mkZellijTheme "default"}
          }
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

      # k9s skin, written against k9s 0.51's config.Style structs
      # (internal/config/styles.go) with k9s's own shipped
      # skins/gruvbox-material-dark-medium.yaml as the structural reference — that
      # is this very palette, so only the placeholders differ. Chrome comes from
      # the surface/outline tones, semantic colors from the terminal ANSI set, as
      # in mkZellijTheme above.
      #
      # Every key the struct defines is set deliberately: k9s fills unset ones
      # from newStyle()'s hardcoded defaults (aqua, dodgerblue, palegreen, black
      # …), which render as off-palette noise rather than as "unthemed".
      #
      # Pairings are chosen for contrast in *both* modes; the ones k9s composites
      # in non-obvious ways are noted at their site. Light-mode accents on the
      # cream surface cap around 3-4:1 (yellow is #b47109 on #f2e5bc) — the
      # palette's ceiling, so accents stay off body text and carry status only.
      #
      # The flash bar (the "Synchronizing … namespace" line) is not themable at
      # all: config.Style has no key for it, and internal/ui/flash.go overwrites
      # the skin foreground per level with hardcoded tcell colors meant for a dark
      # background (1.02:1 on the light surface). Upstream bug; patching k9s or
      # pinning it to the dark palette both cost more than a transient line is
      # worth.
      k9sSkin = (pkgs.formats.yaml { }).generate "noctalia-k9s-skin.yaml" {
        k9s =
          let
            fg = activeColor "on_surface";
            # De-emphasised text: the M3 secondary-text role rather than a grey,
            # because terminal_bright_black is a fixed #928374 in both modes and
            # drops to 2.9:1 on the light surface.
            fgDim = activeColor "on_surface_variant";
            surface = activeColor "surface";
            raised = activeColor "surface_variant";
            outline = activeColor "outline";
            accent = activeColor "primary";
            onAccent = activeColor "on_primary";
            orange = activeColor "secondary";
            red = activeColor "terminal_normal_red";
            green = activeColor "terminal_normal_green";
            yellow = activeColor "terminal_normal_yellow";
            blue = activeColor "terminal_normal_blue";
            magenta = activeColor "terminal_normal_magenta";
            cyan = activeColor "terminal_normal_cyan";
          in
          {
            body = {
              fgColor = fg;
              bgColor = surface;
              logoColor = accent;
              logoColorMsg = fg;
              logoColorInfo = green;
              logoColorWarn = yellow;
              logoColorError = red;
            };

            prompt = {
              fgColor = fg;
              bgColor = surface;
              suggestColor = fgDim;
              border = {
                command = cyan;
                default = outline;
              };
            };

            # Top-level, not under `views`: the old placement parses but is
            # ignored, leaving the help screen on k9s's black default.
            help = {
              fgColor = fg;
              bgColor = surface;
              sectionColor = green;
              keyColor = blue;
              numKeyColor = magenta;
            };

            info = {
              fgColor = accent;
              sectionColor = fg;
              cpuColor = blue;
              memColor = magenta;
              k9sRevColor = fgDim;
            };

            dialog = {
              fgColor = fg;
              bgColor = raised;
              buttonFgColor = fg;
              buttonBgColor = surface;
              buttonFocusFgColor = onAccent;
              buttonFocusBgColor = accent;
              labelFgColor = blue;
              fieldFgColor = fg;
            };

            frame = {
              border = {
                fgColor = outline;
                focusColor = accent;
              };

              menu = {
                fgColor = fg;
                keyColor = green;
                numKeyColor = green;
              };

              # crumbs.go renders `[fgColor:bgColor:b]`, swapping in activeColor
              # as the *background* of the last crumb — one shared foreground over
              # two backgrounds, so both must contrast with it. An accent here put
              # cream text on light green at 1.3:1. Surface tones instead: inactive
              # crumbs melt into the bar, the active one reads as a raised chip.
              crumbs = {
                fgColor = fg;
                bgColor = surface;
                activeColor = raised;
              };

              status = {
                newColor = cyan;
                modifyColor = blue;
                addColor = green;
                pendingColor = orange;
                errorColor = red;
                highlightColor = yellow;
                killColor = fgDim;
                completedColor = fgDim;
              };

              title = {
                fgColor = fg;
                bgColor = raised;
                highlightColor = blue;
                counterColor = cyan;
                filterColor = green;
              };
            };

            views = {
              charts = {
                bgColor = surface;
                dialBgColor = surface;
                chartBgColor = surface;
                focusFgColor = onAccent;
                focusBgColor = accent;
                defaultDialColors = [
                  green
                  red
                ];
                defaultChartColors = [
                  green
                  red
                ];
                # Keyed by k9s's config.CPU / config.MEM constants — note MEM is
                # spelled "memory", not "mem".
                resourceColors = {
                  cpu = [
                    blue
                    magenta
                  ];
                  memory = [
                    yellow
                    orange
                  ];
                };
              };

              table = {
                fgColor = fg;
                bgColor = surface;
                # Selected row. cursorBgColor only lands on an empty table:
                # select_table.go's selectionChanged re-styles the selection as
                # cursorFgColor over the *cell's own* color, so the foreground has
                # to stay legible over every status color below, not just here.
                cursorFgColor = onAccent;
                cursorBgColor = accent;
                markColor = yellow;
                header = {
                  fgColor = fgDim;
                  bgColor = surface;
                  sorterColor = cyan;
                  selectedSortColumnColor = yellow;
                };
              };

              xray = {
                fgColor = fg;
                bgColor = surface;
                cursorColor = accent;
                cursorTextColor = onAccent;
                graphicColor = cyan;
              };

              yaml = {
                keyColor = magenta;
                colonColor = fgDim;
                valueColor = fg;
              };

              picker = {
                mainColor = fg;
                focusColor = accent;
                shortcutColor = yellow;
              };

              logs = {
                fgColor = fg;
                bgColor = surface;
                indicator = {
                  fgColor = fg;
                  bgColor = raised;
                  toggleOnColor = green;
                  toggleOffColor = fgDim;
                };
              };
            };
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

      # noctalia is the theme authority for every app it templates (foot, helix,
      # zellij, niri, starship, bat, GTK, Firefox, Obsidian, k9s, Claude Code) —
      # each one renders live and follows the day/night mode. ./appearance.nix
      # owns what has no live story: fonts, cursor, wallpaper, GTK base theme.

      # Seed noctalia's wallpaper folder. Drop more images into this dir (another
      # xdg.configFile entry) and noctalia will offer them.
      xdg.configFile."noctalia/wallpapers/gruvbox-stairs.jpg".source = appearance.wallpaper;

      # Install the pywalfox native-messaging manifest (noctalia is the pywalfox
      # host; the Pywalfox extension is added in modules/desktop/firefox.nix).
      # Letting the binary emit it keeps the manifest from drifting from the pinned
      # noctalia input; re-running on every activation self-heals it after each
      # tmpfs-root boot wipes ~/.mozilla (so no preservation entry needed), and
      # install() only writes when absent/noctalia-owned, so it's safe to repeat.
      home.activation.noctaliaFirefoxHost = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${config.programs.noctalia.package}/bin/noctalia firefox-theme install
      '';

      # Put footThemeFallback in place before the session; noctalia overwrites it with
      # the live palette seconds later. Skipped when the file exists so a mid-session
      # `nh os switch` doesn't revert a runtime palette change.
      home.activation.footNoctaliaTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        [ -e "${footThemeFile}" ] || run install -Dm644 ${footThemeFallback} "${footThemeFile}"
      '';

      programs = {
        # Point each app at the theme file noctalia renders for it. Declaring this
        # ourselves keeps it declarative: foot is a user template now, so no apply.sh
        # runs for it; helix has no hook and just loads the named theme.
        foot.settings.main.include = footThemeFile;
        helix.settings.theme = lib.mkForce "noctalia";

        # zellij: `noctalia` is the live-mode block, so a session started at any
        # point opens on the current palette; the dark/light pair is what the
        # post_hook (and zellij's own detection) switches a running session to.
        # Overrides the builtin ../zellij/zellij.nix falls back to off-desktop.
        zellij.settings = {
          theme = lib.mkForce "noctalia";
          theme_dark = "noctalia-dark";
          theme_light = "noctalia-light";
        };

        # starship: STARSHIP_CONFIG points at the noctalia-rendered cache file (see
        # starshipTemplate above) so the prompt follows the live light/dark mode.
        # The HM-managed ~/.config/starship.toml symlink is left unused (read-only,
        # so noctalia can't write it in place).
        nushell.environmentVariables.STARSHIP_CONFIG = "${config.home.homeDirectory}/.cache/starship.toml";

        # bat: via HM's option rather than nushell's alias, so every shell gets it —
        # and HM owns that config file, so this isn't the in-place apply.sh rewrite we
        # avoid elsewhere. bat is spawned fresh per invocation, so no reload hook.
        bat.config.theme = lib.mkForce "noctalia";

        # Claude Code: "custom:<slug>" selects $CLAUDE_CONFIG_DIR/themes/<slug>.json.
        # Set here rather than in modules/claude/claude.nix (into whose settings it
        # merges) so it only lands on hosts that run noctalia to render that file.
        claude-code.settings.theme = "custom:noctalia";

        # k9s: names the skin noctalia renders to ~/.config/k9s/skins/. Set here
        # rather than in modules/kubernetes/kubernetes.nix for the same reason as
        # claude-code above. Both keys are load-bearing and fail silently:
        #   k9s.  config.yaml is `Config{ K9s *K9s yaml:"k9s" }`, schema-validated
        #         with additionalProperties:false, so a bare `ui.skin` is dropped
        #         and k9s falls back to its stock skin.
        #   reactive.  App.Resume only starts SkinsDirWatcher when it is set;
        #         without it a running k9s picks up a re-render only on restart.
        k9s.settings.k9s.ui = {
          skin = "noctalia";
          reactive = true;
        };

        noctalia = {
          enable = true;

          settings = {
            theme = {
              # Gruvbox Material — noctalia has no builtin for it, so the palette
              # is vendored as JSON (gruvboxMaterial above, both variants).
              #
              # auto = follow day/night from location (auto_locate below). Every
              # templated surface switches with it; the fixed pieces in
              # ./appearance.nix (fonts, cursor, wallpaper) are mode-independent.
              mode = "auto";
              source = "custom";
              custom_palette = "gruvbox-material";

              # The links/includes above are what make each app pick these up.
              templates = {
                enable_builtin_templates = true;
                builtin_ids = [
                  # No "foot": the `foot` user template below replaces it.
                  "helix"
                  "niri"
                  # GTK colors only — GTK apps (Nautilus, file-picker dialogs) follow
                  # the live day/night palette. ./appearance.nix keeps the base
                  # theme/cursor/font and declares the `@import` that pulls the
                  # rendered noctalia.css in, so apply.sh finds it present and won't
                  # rewrite the read-only gtk.css symlink. (electron apps ignore GTK
                  # for their inner UI.)
                  "gtk3"
                  "gtk4"
                ];
                # Each template's render logic + reasoning is on its `let` binding
                # above; comments here note only per-app render hooks.
                user = {
                  # post_hook signals the foot *server*, which switches every current
                  # and future client window: SIGUSR1 = [colors-dark], SIGUSR2 =
                  # [colors-light]. `-x` skips the footclient processes (the server
                  # covers their windows); `|| true` tolerates no server yet.
                  foot = {
                    enabled = true;
                    input_path = "${footThemeTemplate}";
                    output_path = footThemeFile;
                    post_hook = ''if [ "{{ mode }}" = light ]; then ${pkgs.procps}/bin/pkill -USR2 -x foot; else ${pkgs.procps}/bin/pkill -USR1 -x foot; fi || true'';
                  };
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
                  # Likewise k9s, which watches its config dir and re-reads the skin.
                  k9s = {
                    enabled = true;
                    input_path = "${k9sSkin}";
                    output_path = "~/.config/k9s/skins/noctalia.yaml";
                  };
                  # wal-format palette for the Pywalfox extension: color0..15 are
                  # the ANSI terminal colors, which is what pywalfox maps onto
                  # Firefox's theme keys. All sixteen need a value — noctalia
                  # forwards them verbatim, so an empty string lands in the theme
                  # as a color. The community `pywalfox-beta4` template this
                  # replaces left nine of them "".
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
              # Bar/launcher/panel *text* only — the icons come from noctalia's own
              # bundled tabler.ttf, so no nerd-font coverage is needed here. Inheriting
              # The shared UI sans (./appearance.nix) keeps the shell on the same
              # font as the GTK apps.
              font_family = appearance.font.name;

              # The wizard's only "already done" marker lives in ~/.local/state, which
              # the tmpfs root wipes, so it would run at every login — and what it asks
              # for (palette, wallpaper, bar) is declarative here anyway.
              setup_wizard_enabled = false;

              niri_overview_type_to_launch_enabled = true;
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

            # Blurred/tinted copy of the wallpaper on its own background surface
            # (namespace noctalia-backdrop), which ./niri.nix's layer-rule places in
            # niri's overview backdrop. Off by default in noctalia, and the layer-rule
            # matches nothing without it. blur/tint are 0..1.
            backdrop = {
              enabled = true;
              blur_intensity = 0.5;
              tint_intensity = 0.3;
            };

            wallpaper = {
              # Seeded with appearance.wallpaper via xdg.configFile above.
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
