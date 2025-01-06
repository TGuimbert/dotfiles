{ pkgs, ... }:
{
  programs.helix = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      marksman
      ltex-ls
      yaml-language-server
      nodePackages.prettier
    ];
    ignores = [
      ".obsidian/"
      ".direnv/"
      ".envrc"
    ];
    languages = {
      language = [
        {
          name = "markdown";
          language-servers = [
            "marksman"
            "ltex-ls"
          ];
          formatter = {
            command = "dprint";
            args = [
              "fmt"
              "--stdin"
              "md"
            ];
          };
          auto-format = true;
        }
        {
          name = "nix";
          formatter = {
            command = "nixfmt";
          };
          auto-format = true;
        }
        {
          name = "go";
          auto-format = true;
          formatter = {
            command = "goimports";
          };
        }
        {
          name = "yaml";
          auto-format = true;
          formatter = {
            command = "prettier";
            args = [
              "--parser"
              "yaml"
            ];
          };
        }
      ];
      language-server.yaml-language-server.config.yaml = {
        completion = true;
        validation = true;
        hover = true;
        schemas = {
          "https://json.schemastore.org/github-workflow.json" = ".github/workflows/*.{yml,yaml}";
          "https://raw.githubusercontent.com/ansible-community/schemas/main/f/ansible-tasks.json" =
            "roles/{tasks,handlers}/*.{yml,yaml}";
          kubernetes = [
            "*deployment*.yaml"
            "*service*.yaml"
            "*configmap*.yaml"
            "*secret*.yaml"
            "*pod*.yaml"
            "*namespace*.yaml"
            "*ingress*.yaml"
          ];
          "https://raw.githubusercontent.com/SchemaStore/schemastore/master/src/schemas/json/kustomization.json" =
            [
              "*kustomization.yaml"
              "*kustomize.yaml"
            ];
        };
      };
    };
    settings = {
      editor = {
        bufferline = "multiple";
        color-modes = true;
        rulers = [ 120 ];
        line-number = "relative";
        end-of-line-diagnostics = "hint";
      };

      editor.cursor-shape = {
        normal = "block";
        insert = "bar";
        select = "underline";
      };

      editor.indent-guides = {
        render = true;
      };

      editor.file-picker = {
        hidden = false;
      };

      editor.statusline = {
        left = [
          "mode"
          "spinner"
          "version-control"
          "file-name"
          "read-only-indicator"
          "file-modification-indicator"
        ];
      };

      editor.inline-diagnostics = {
        cursor-line = "error";
      };

      keys.normal = {
        g = "move_char_left";
        t = "move_line_down";
        s = "move_line_up";
        n = "move_char_right";

        j = "find_till_char";
        J = "till_prev_char";

        T = "join_selections";

        l = "search_next";
        L = "search_prev";

        k = "select_regex";
        K = "split_selection";
        "A-k" = "split_selection_on_newline";

        h = {
          h = "goto_file_start";
          e = "goto_last_line";
          f = "goto_file";
          g = "goto_line_start";
          n = "goto_line_end";
          s = "goto_first_nonwhitespace";
          t = "goto_window_top";
          c = "goto_window_center";
          b = "goto_window_bottom";
          d = "goto_definition";
          y = "goto_type_definition";
          r = "goto_reference";
          i = "goto_implementation";
          a = "goto_last_accessed_file";
          m = "goto_last_modified_file";
          l = "goto_next_buffer";
          p = "goto_previous_buffer";
          "." = "goto_last_modification";
        };
      };

      keys.select = {
        l = "extend_search_next";
        L = "extend_search_prev";
      };
    };
  };
}
