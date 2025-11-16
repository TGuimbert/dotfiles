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
        {
          name = "python";
          language-servers = [
            "ruff"
            "pylsp"
          ];
          auto-format = true;
        }
        {
          name = "hcl";
          language-id = "opentofu";
          scope = "source.hcl";
          file-types = [
            "tf"
            "tofu"
            "tfvars"
          ];
          auto-format = true;
          comment-token = "#";
          block-comment-tokens = {
            start = "/*";
            end = "*/";
          };
          indent = {
            tab-width = 2;
            unit = "  ";
          };
          language-servers = [ "tofu-ls" ];
        }
      ];
      language-server = {
        yaml-language-server.config.yaml = {
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
        pylsp.config.pylsp = {
          plugins.pylsp_mypy.enabled = true;
          plugins.pylsp_mypy.live_mode = true;
        };
        ruff = {
          command = "ruff";
          arg = [ "server" ];
        };
        tofu-ls = {
          command = "tofu-ls";
          args = [ "serve" ];
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
    };
  };
}
