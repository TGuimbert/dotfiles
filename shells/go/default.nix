{ pkgs, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    go # Go
    gotools # Go tools like goimports, godoc, and others
    gopls # Go language server
    delve # Go debugger
    golangci-lint # Better Go linter
    golangci-lint-langserver # Golangci-lint lsp
    errcheck # Checks for unchecked errors in go programs
  ];
}

