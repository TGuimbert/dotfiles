{ ... }:
{
  homeManager.modules.base =
    { pkgs, ... }:
    {
      programs.nushell = {
        enable = true;
        plugins = [ pkgs.nushellPlugins.formats ];

        # Not `home.sessionVariables`: home-manager's nushell module does not
        # read those. Matters now that nu is the login shell (./user.nix) — over
        # ssh there is no graphical session to have exported them.
        environmentVariables = {
          EDITOR = "hx";
          VISUAL = "hx";
          CARAPACE_BRIDGES = "zsh,fish,bash,inshellisense";
          ZELLIJ_AUTO_ATTACH = "true";
          ZELLIJ_AUTO_EXIT = "true";
        };

        settings = {
          show_banner = false;
          buffer_editor = "hx";
        };

        shellAliases = {
          ll = "ls -la";
          cat = "bat";
          b = "bash -c";
          bash = "/run/current-system/sw/bin/bash";

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
        };

        extraEnv = ''
          if (not ("~/.config/nushell/private.nu" | path exists)) {
            touch ~/.config/nushell/private.nu
          }
        '';

        extraConfig = ''
          use std

          # List existing Zellij layouts
          def available-layouts [] {
            ls ~/.config/zellij/layouts/ | get name | path parse | get stem
          }

          # Replace current Zellij tab with a new one based on the specified layout
          def replace-with-layout [layout: string@available-layouts] {
            let temp_tab_name = random chars
            zellij action rename-tab $temp_tab_name
            zellij action new-tab --layout $layout --name ($env.PWD | path basename)
            zellij action go-to-tab-name $temp_tab_name
            zellij action close-tab
          }

          source ~/.config/nushell/private.nu
          use ${pkgs.nu_scripts}/share/nu_scripts/aliases/eza/eza-aliases.nu *
        '';
      };

      programs.carapace.enable = true;
    };

  homeManager.modules.gui.programs.nushell.extraConfig = ''
    # Open in a browser a local copy of the rust documentation
    def open-rust-doc [] {
      xdg-open (nix build fenix#latest.rust-docs --json --no-link | from json | first | get outputs.out | path join share/doc/rust/html/index.html)
    }
  '';

  nixos.modules.base.preservation.preserveAt."/persistent".users.tguimbert.files = [
    ".config/nushell/history.txt"
    ".config/nushell/private.nu"
  ];
}
