{ config, ... }:
{
  homeManager.modules.base.imports = [ config.homeManager.modules.nushell ];

  homeManager.modules.nushell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.programs.nushell;
      # The Linux-only mutable config follows Home Manager's configDir, including
      # a consumer's relative or absolute override. macOS has no private file.
      configDir =
        if lib.hasPrefix "/" (toString cfg.configDir) then
          toString cfg.configDir
        else
          "${config.home.homeDirectory}/${cfg.configDir}";
      nuString = lib.hm.nushell.toNushell { };
      privateFile = nuString "${configDir}/private.nu";
      openCommand =
        if pkgs.stdenv.isDarwin then "/usr/bin/open" else lib.getExe' pkgs.xdg-utils "xdg-open";
    in
    {
      programs.nushell = {
        enable = true;
        # Override the shell and formats plugin together when changing nixpkgs.
        plugins = [ pkgs.nushellPlugins.formats ];

        environmentVariables = lib.mkMerge [
          { CARAPACE_BRIDGES = "zsh,fish,bash,inshellisense"; }
          (lib.mkIf config.programs.helix.enable {
            EDITOR = lib.mkDefault "hx";
            VISUAL = lib.mkDefault "hx";
          })
          (lib.mkIf config.programs.zellij.enable {
            ZELLIJ_AUTO_ATTACH = lib.mkDefault "true";
            ZELLIJ_AUTO_EXIT = lib.mkDefault "true";
          })
        ];

        settings = {
          show_banner = false;
          buffer_editor = lib.mkIf config.programs.helix.enable (lib.mkDefault "hx");
        };

        shellAliases = lib.mkMerge [
          {
            ll = "ls -la";
            b = "${lib.getExe pkgs.bash} -c";
            bash = lib.getExe pkgs.bash;
          }
          (lib.mkIf config.programs.bat.enable { cat = "bat"; })
          (lib.mkIf config.programs.git.enable {
            gs = "git status";
            gd = "git diff";
            gds = "git diff --staged";
            ga = "git add";
            gap = "git add --patch";
            gc = "git commit";
            gca = "git commit --amend --no-edit";
            gce = "git commit --amend";
            gp = "git push";
            gu = "git pull";
            gco = "git checkout";
            gsw = "git switch";
            gn = "git switch --create";
            gl = ''git log --graph --all --pretty=format:"%C(magenta)%h %C(white) %an  %ar%C(blue)  %D%n%s%n"'';
            gb = "git branch";
          })
        ];

        # Retain the existing Linux private config. Darwin consumers configure
        # extraEnv/extraConfig directly in their own private configuration repo.
        extraEnv = lib.mkIf (!pkgs.stdenv.isDarwin) ''
          mkdir ${nuString configDir}
          if (not (${privateFile} | path exists)) {
            touch ${privateFile}
          }
        '';

        extraConfig = lib.mkMerge [
          ''
            use std
            ${lib.optionalString (!pkgs.stdenv.isDarwin) "source ${privateFile}"}

            # Resolve the opener on the host running Nushell.
            def open-rust-doc [] {
              ${openCommand} (nix build fenix#latest.rust-docs --json --no-link | from json | first | get outputs.out | path join share/doc/rust/html/index.html)
            }
          ''
          (lib.mkIf config.programs.eza.enable ''
            use ${pkgs.nu_scripts}/share/nu_scripts/aliases/eza/eza-aliases.nu *
          '')
          (lib.mkIf config.programs.zellij.enable ''
            def available-layouts [] {
              glob (${nuString config.xdg.configHome} | path join zellij layouts "*.kdl") | path parse | get stem
            }

            def replace-with-layout [layout: string@available-layouts] {
              let temp_tab_name = random chars
              zellij action rename-tab $temp_tab_name
              zellij action new-tab --layout $layout --name ($env.PWD | path basename)
              zellij action go-to-tab-name $temp_tab_name
              zellij action close-tab
            }
          '')
        ];
      };

      programs.carapace.enable = true;
    };

  nixos.modules.base.preservation.preserveAt."/persistent".users.tguimbert.files = [
    ".config/nushell/history.txt"
    ".config/nushell/private.nu"
  ];
}
