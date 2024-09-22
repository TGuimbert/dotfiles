{ ... }:
{
  programs.helix = {
    enable = true;
    defaultEditor = true;
    ignores = [
      ".obsidian/"
      ".direnv/"
      ".envrc"
    ];
    languages = {
      language = [
        {
          name = "markdown";
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
      ];
    };
    settings = {
      theme = "gruvbox";

      editor = {
        bufferline = "multiple";
        color-modes = true;
        rulers = [ 120 ];
        line-number = "relative";
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
