{ ... }:

{
  home.sessionVariables = {
    EDITOR = "hx";
  };

  programs.helix = {
    enable = true;
    settings = {
      theme = "gruvbox-zellij";

      editor = {
        bufferline = "multiple";
        color-modes = true;
        rulers = [ 80 ];
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
    themes = {
      # Workaround for this bug https://github.com/zellij-org/zellij/issues/1594
      gruvbox-zellij = {
        "inherits" = "gruvbox";
        "diagnostic.warning" = { "underline" = { "color" = "orange1"; "style" = "line"; }; };
        "diagnostic.error" = { "underline" = { "color" = "red1"; "style" = "line"; }; };
        "diagnostic.info" = { "underline" = { "color" = "aqua1"; "style" = "line"; }; };
        "diagnostic.hint" = { "underline" = { "color" = "blue1"; "style" = "line"; }; };
      };
    };
  };
}
