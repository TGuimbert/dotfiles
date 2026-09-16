{
  config,
  lib,
  pkgs,
}:
lib.mkMerge [
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
]
