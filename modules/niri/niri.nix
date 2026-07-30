# niri (scrollable-tiling Wayland compositor). Opt-in aspect — imported only by
# hosts that want it (currently leshen). Its shell/theming half lives alongside
# in ./noctalia.nix, which merges into this same `niri` home-manager aspect, so
# importing `niri` pulls both. GNOME stays installed as a fallback session; GDM
# lets you pick niri or GNOME at login.
{ config, inputs, ... }:
{
  nixos.modules.niri =
    { pkgs, ... }:
    {
      imports = [ inputs.niri.nixosModules.niri ];

      programs.niri = {
        enable = true;
        # niri-unstable is required for the built-in xwayland-satellite
        # integration below (X11 apps / Steam games — leshen imports `games`).
        # Both niri-stable and niri-unstable are served by niri.cachix.org.
        package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
      };

      # Bridge the niri home-manager aspect onto this host (mirrors the `gui`
      # bridge in modules/users.nix).
      home-manager.users.tguimbert.imports = [ config.homeManager.modules.niri ];

      # External-monitor brightness: leshen has no internal panel, so noctalia
      # drives the displays over DDC/CI (via ddcutil + i2c-dev) instead of sysfs
      # backlight. tguimbert joins the `i2c` group for unprivileged access. DDC/CI
      # must be enabled in each monitor's OSD; verify with `ddcutil detect` (both
      # DP outputs should report VCP 0x10).
      hardware.i2c.enable = true;
      users.users.tguimbert.extraGroups = [ "i2c" ];
      environment.systemPackages = [ pkgs.ddcutil ];

      # NB: noctalia 5 keeps its runtime state (settings overrides, wallpaper choice,
      # notification history, wizard marker) in ~/.local/state/noctalia — this dir
      # holds only HM symlinks now, so the entry carries nothing. Preserve the state
      # dir instead if that state should survive.
      preservation.preserveAt."/persistent".users.tguimbert.directories = [
        ".config/noctalia"
        # where screenshot-path (below) writes
        "Pictures/Screenshots"
      ];
    };

  # Hands the lid to the compositor so it can lock *before* suspending (the
  # switch-events bind below) instead of racing logind and resuming unlocked. Opt-in
  # per host rather than part of `niri`: logind is system-wide, so on a host that
  # also offers the GNOME session this takes the lid away from GNOME too. Import
  # next to `niri` from a laptop machine file (griffin, once it moves off GNOME).
  nixos.modules.niriLaptop.services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # Compositor half of the home-manager `niri` aspect (./noctalia.nix adds the
  # shell/theming half).
  homeManager.modules.niri =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # niri's home config (programs.niri.settings + config.lib.niri.actions) is
      # auto-imported into this user by inputs.niri.nixosModules.niri.

      # playerctl backs the XF86Audio{Play,Next,Prev} media-key binds below.
      home.packages = [ pkgs.playerctl ];

      # noctalia's builtin `niri` template renders the colors to
      # ~/.config/niri/noctalia.kdl, and its apply.sh injects the include into
      # config.kdl — which it can't do here, ours being a read-only HM symlink. So
      # declare the include ourselves; apply.sh greps for one and skips its write.
      # `optional=true` survives a fresh tmpfs boot with the file not yet rendered,
      # and niri live-reloads once it appears, so no reload hook is needed. Appending
      # to finalConfig (not config, which would cycle) keeps the structured settings
      # below.
      xdg.configFile.niri-config.source = lib.mkForce (
        pkgs.writeText "niri-config.kdl" ''
          ${config.programs.niri.finalConfig}
          include optional=true "noctalia.kdl"
        ''
      );

      programs.niri.settings = {
        prefer-no-csd = true;

        # Input — xkb mirrors the system layout (us/intl + fr/oss AZERTY,
        # modules/locale.nix) so niri, the console and GNOME agree. Touchpad
        # settings are sane defaults for when a laptop host (griffin) later imports
        # this aspect; leshen is a desktop with no touchpad, so they're inert there.
        input = {
          keyboard = {
            xkb = {
              layout = "us,fr";
              variant = "intl,oss";
              # fr(oss) is AZERTY; toggle us(intl) <-> AZERTY with Scroll Lock
              # (KC_SCRL on a Miryoku layer).
              options = "grp:sclk_toggle";
            };
            repeat-delay = 300;
            repeat-rate = 50;
          };
          mouse.accel-profile = "flat";
          touchpad = {
            tap = true;
            dwt = true; # disable-while-typing
            natural-scroll = true;
            click-method = "clickfinger";
            scroll-method = "two-finger";
          };
          # Pointer follows keyboard focus and vice-versa — handy across the two
          # monitors. warp-mouse-to-focus teleports the cursor to a newly focused
          # window so it's never lost on the other screen.
          focus-follows-mouse.enable = true;
          warp-mouse-to-focus.enable = true;
        };

        # Layout — scrollable-tiling geometry. No `struts`: noctalia's bar is a
        # layer-shell surface with an exclusive zone, so niri already reserves its
        # space; a strut would double-count it. focus-ring / border *colours* come
        # from noctalia's niri.kdl (included after this config, so it wins), so only
        # structural values are set here to avoid fighting over the palette.
        layout = {
          gaps = 12;
          center-focused-column = "never";
          # Cycled by Mod+R (switch-preset-column-width); nudged by Mod+Minus/Equal.
          preset-column-widths = [
            { proportion = 1.0 / 3.0; }
            { proportion = 1.0 / 2.0; }
            { proportion = 2.0 / 3.0; }
          ];
          default-column-width.proportion = 1.0 / 2.0;
          preset-window-heights = [
            { proportion = 1.0 / 3.0; }
            { proportion = 1.0 / 2.0; }
            { proportion = 2.0 / 3.0; }
          ];
        };

        # Mod+Shift+Slash still shows the cheatsheet on demand.
        hotkey-overlay.skip-at-startup = true;
        gestures.hot-corners.enable = true;

        # Interactive (Mod+Print) and full screen/window screenshots land here,
        # timestamped so they sort. ~/Pictures/Screenshots is preserved in the
        # nixos aspect above so they survive the tmpfs-root reboots.
        screenshot-path = "~/Pictures/Screenshots/screenshot-%Y-%m-%d-%H-%M-%S.png";

        # Session-wide env for Wayland-native rendering of the apps niri spawns.
        # (No global equivalent is set elsewhere in the repo.) DISPLAY is left to
        # xwayland-satellite, which exports it for the X11 clients it serves.
        environment = {
          NIXOS_OZONE_WL = "1";
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
          MOZ_ENABLE_WAYLAND = "1";
          QT_QPA_PLATFORM = "wayland;xcb";
        };

        # Needs `niriLaptop` (above) to take the lid off logind. Inert on leshen,
        # which has no lid switch, like the touchpad settings above. Switch binds
        # accept nothing but spawn actions.
        switch-events.lid-close.action.spawn = [
          "noctalia"
          "msg"
          "session"
          "lock-and-suspend"
        ];

        # Without this, apps launched from noctalia's launcher open unfocused
        # (upstream's recommendation). An empty argument list is how niri-flake
        # spells a no-argument `debug` node.
        debug.honor-xdg-activation-with-invalid-serial = [ ];

        # Window rules — matched top-to-bottom, later rules layer over earlier.
        window-rules = [
          {
            geometry-corner-radius =
              let
                r = 8.0;
              in
              {
                top-left = r;
                top-right = r;
                bottom-left = r;
                bottom-right = r;
              };
            clip-to-geometry = true;
          }
          # Picture-in-Picture (Firefox / mpv) floats instead of joining a column.
          {
            matches = [
              { title = "^Picture-in-Picture$"; }
              { title = "^Picture in picture$"; }
            ];
            open-floating = true;
          }
          {
            matches = [
              {
                app-id = "^firefox$";
                title = "^Extension: \\(Bitwarden";
              }
            ];
            open-floating = true;
          }
          # noctalia's own window (its settings UI when opened windowed rather than as
          # a panel) floats at the size upstream recommends, instead of taking a column.
          {
            matches = [ { app-id = "^dev\\.noctalia\\.Noctalia$"; } ];
            open-floating = true;
            default-column-width.fixed = 1080;
            default-window-height.fixed = 920;
          }
          # Template for keeping secrets out of screencasts (noctalia screen-share,
          # OBS): add a rule matching your password manager's app-id and set
          # `block-out-from = "screencast";` — left empty until one is installed.
        ];

        # Puts noctalia's blurred wallpaper behind the overview and the gaps between
        # workspaces, in place of niri's flat backdrop colour. It paints that on a
        # *second* background surface — distinct from the plain noctalia-wallpaper one
        # — which exists only while `backdrop.enabled` is set in ./noctalia.nix.
        layer-rules = [
          {
            matches = [ { namespace = "^noctalia-backdrop"; } ];
            place-within-backdrop = true;
          }
        ];

        # Dual 2560x1440 @ scale 1, side by side. DP-1 (XF270HU, 144 Hz + VRR) is
        # the primary on the left; DP-2 (VG270U, 75 Hz) sits to its right.
        # position.x is in logical pixels (scale 1 here, so 2560 == panel width).
        outputs = {
          "DP-1" = {
            mode = {
              width = 2560;
              height = 1440;
              refresh = 143.856;
            };
            scale = 1.0;
            position = {
              x = 0;
              y = 0;
            };
            # on-demand = VRR only for fullscreen VRR windows (games); avoids the
            # desktop brightness flicker some panels show with VRR always on.
            variable-refresh-rate = "on-demand";
            focus-at-startup = true;
          };
          "DP-2" = {
            mode = {
              width = 2560;
              height = 1440;
              refresh = 74.924;
            };
            scale = 1.0;
            position = {
              x = 2560;
              y = 0;
            };
          };
        };

        xwayland-satellite = {
          enable = true;
          path =
            lib.getExe
              inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.xwayland-satellite-unstable;
        };

        # noctalia replaces the bar/launcher/notifications — start it with niri.
        # (systemd startup is deprecated by noctalia; spawn-at-startup instead.)
        spawn-at-startup = [
          { command = [ "noctalia" ]; }
        ];

        binds = with config.lib.niri.actions; {
          # apps — footclient reuses the existing foot server (modules/terminal.nix).
          "Mod+T" = {
            action = spawn "footclient";
            hotkey-overlay.title = "Open a terminal";
          };
          "Mod+E" = {
            action = spawn "nautilus";
            hotkey-overlay.title = "Open the file manager";
          };

          # noctalia panels via its `msg` IPC. Settings are reached from the
          # control-center (Mod+S), so Mod+Comma is freed for consume-into-column.
          "Mod+Space" = {
            action = spawn "noctalia" "msg" "panel-toggle" "launcher";
            hotkey-overlay.title = "Open the launcher";
          };
          "Mod+S" = {
            action = spawn "noctalia" "msg" "panel-toggle" "control-center";
            hotkey-overlay.title = "Open the control center";
          };
          "Alt+Tab" = {
            action = spawn "noctalia" "msg" "window-switcher";
            hotkey-overlay.title = "Switch windows";
          };

          # window / focus management (niri defaults)
          "Mod+Q".action = close-window;
          "Mod+F".action = maximize-column;
          "Mod+Shift+F".action = fullscreen-window;
          "Mod+R".action = switch-preset-column-width;
          "Mod+Shift+E".action = quit;
          "Mod+Shift+Slash".action = show-hotkey-overlay;

          "Mod+Left".action = focus-column-left;
          "Mod+Right".action = focus-column-right;
          "Mod+Down".action = focus-window-down;
          "Mod+Up".action = focus-window-up;
          "Mod+H".action = focus-column-left;
          "Mod+L".action = focus-column-right;
          "Mod+J".action = focus-window-down;
          "Mod+K".action = focus-window-up;

          "Mod+Ctrl+Left".action = move-column-left;
          "Mod+Ctrl+Right".action = move-column-right;
          "Mod+Ctrl+Down".action = move-window-down;
          "Mod+Ctrl+Up".action = move-window-up;

          "Mod+Home".action = focus-column-first;
          "Mod+End".action = focus-column-last;
          "Mod+Ctrl+Home".action = move-column-to-first;
          "Mod+Ctrl+End".action = move-column-to-last;

          # column composition — the scrollable-tiling core. Consume pulls the
          # next window into the focused column (Mod+Comma, reclaimed from
          # settings); expel pushes it back out. Bracket keys do it directionally.
          "Mod+Comma".action = consume-window-into-column;
          "Mod+Period".action = expel-window-from-column;
          "Mod+BracketLeft".action = consume-or-expel-window-left;
          "Mod+BracketRight".action = consume-or-expel-window-right;

          "Mod+Minus".action = set-column-width "-10%";
          "Mod+Equal".action = set-column-width "+10%";
          "Mod+Shift+Minus".action = set-window-height "-10%";
          "Mod+Shift+Equal".action = set-window-height "+10%";
          "Mod+Ctrl+F".action = expand-column-to-available-width;
          "Mod+C".action = center-column;

          "Mod+W".action = toggle-column-tabbed-display;
          "Mod+V".action = toggle-window-floating;
          "Mod+Shift+V".action = switch-focus-between-floating-and-tiling;

          # multi-monitor (leshen is dual-output). Shift = focus the other screen,
          # Ctrl+Shift = drag the column there.
          "Mod+Shift+Left".action = focus-monitor-left;
          "Mod+Shift+Right".action = focus-monitor-right;
          "Mod+Ctrl+Shift+Left".action = move-column-to-monitor-left;
          "Mod+Ctrl+Shift+Right".action = move-column-to-monitor-right;

          # the hot corner (enabled above) toggles this too
          "Mod+O".action = toggle-overview;

          "Mod+Page_Down".action = focus-workspace-down;
          "Mod+Page_Up".action = focus-workspace-up;
          "Mod+1".action = focus-workspace 1;
          "Mod+2".action = focus-workspace 2;
          "Mod+3".action = focus-workspace 3;
          "Mod+4".action = focus-workspace 4;
          "Mod+Ctrl+Page_Down".action = move-column-to-workspace-down;
          "Mod+Ctrl+Page_Up".action = move-column-to-workspace-up;
          "Mod+Shift+Page_Down".action = move-workspace-down;
          "Mod+Shift+Page_Up".action = move-workspace-up;

          # Mod+scroll to move between workspaces / columns (cooldown debounces
          # a fast wheel so one flick isn't several steps).
          "Mod+WheelScrollDown" = {
            action = focus-workspace-down;
            cooldown-ms = 150;
          };
          "Mod+WheelScrollUp" = {
            action = focus-workspace-up;
            cooldown-ms = 150;
          };
          "Mod+WheelScrollRight".action = focus-column-right;
          "Mod+WheelScrollLeft".action = focus-column-left;

          # screenshots — Mod+Print opens the interactive region UI (screenshot-path
          # above); modifiers grab the whole screen / focused window straight to disk.
          "Mod+Print".action.screenshot = { };
          "Ctrl+Print".action.screenshot-screen = { };
          "Alt+Print".action.screenshot-window = { };

          # volume through noctalia so its OSD shows.
          "XF86AudioRaiseVolume" = {
            action = spawn "noctalia" "msg" "volume-up";
            hotkey-overlay.title = "Volume up";
          };
          "XF86AudioLowerVolume" = {
            action = spawn "noctalia" "msg" "volume-down";
            hotkey-overlay.title = "Volume down";
          };
          "XF86AudioMute" = {
            action = spawn "noctalia" "msg" "volume-mute";
            hotkey-overlay.title = "Toggle mute";
          };
          # playerctl (not noctalia msg) drives transport — a standard MPRIS
          # client that works regardless of noctalia's IPC surface.
          "XF86AudioPlay" = {
            action = spawn "playerctl" "play-pause";
            hotkey-overlay.title = "Play / pause media";
          };
          "XF86AudioNext" = {
            action = spawn "playerctl" "next";
            hotkey-overlay.title = "Next track";
          };
          "XF86AudioPrev" = {
            action = spawn "playerctl" "previous";
            hotkey-overlay.title = "Previous track";
          };

          # External-monitor brightness over DDC/CI, routed through noctalia so it
          # shows the OSD and respects the ddcutil path enabled above.
          "XF86MonBrightnessUp" = {
            action = spawn "noctalia" "msg" "brightness-up";
            hotkey-overlay.title = "Brightness up";
          };
          "XF86MonBrightnessDown" = {
            action = spawn "noctalia" "msg" "brightness-down";
            hotkey-overlay.title = "Brightness down";
          };

          # Lock on demand (noctalia is the lock authority; cf. the idle config).
          "Super+Alt+L" = {
            action = spawn "noctalia" "msg" "session" "lock";
            hotkey-overlay.title = "Lock the screen";
          };
        };
      };
    };
}
