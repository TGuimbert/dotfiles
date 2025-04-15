{ pkgs, lib, ... }:
let
  flux-view = gvr: {
    "${gvr}" = {
      "columns" =
        [
          "NAME"
        ]
        ++ (lib.optionals (lib.hasPrefix "source.toolkit.fluxcd.io/" gvr) [ "URL" ])
        ++ [
          "READY"
          "SUSPENDED:.spec.suspend"
          "STATUS"
          "STATUS TIME:status.conditions[0].lastTransitionTime|T"
          "AGE"
        ];
    };
  };
  toggle-suspend =
    name: gvr:
    lib.nameValuePair ("toggle-suspend-" + name) {
      shortCut = "Shift-T";
      description = "Toggle suspend";
      confirm = true;
      scopes = [
        (lib.last (builtins.split "/" gvr))
      ];
      command = "bash";
      background = true;
      args = [
        "-c"
        "verb=$([ $COL-SUSPENDED ] && echo \"resume\" || echo \"suspend\"); flux $verb ${lib.optionalString (lib.hasPrefix "source.toolkit.fluxcd.io/" gvr) "source"} ${name} --context $CONTEXT -n $NAMESPACE $NAME"
      ];
    };
  reconcile =
    name: gvr:
    lib.nameValuePair ("reconcile-" + name) {
      shortCut = "Shift-R";
      description = "Flux reconcile";
      confirm = false;
      scopes = [
        (lib.last (builtins.split "/" gvr))
      ];
      command = "bash";
      background = true;
      args = [
        "-c"
        "flux reconcile ${lib.optionalString (lib.hasPrefix "source.toolkit.fluxcd.io/" gvr) "source"} ${name} --context $CONTEXT -n $NAMESPACE $NAME"
      ];
    };
  flux-resources = {
    "kustomization" = "kustomize.toolkit.fluxcd.io/v1/kustomizations";
    "helmrelease" = "helm.toolkit.fluxcd.io/v2/helmreleases";
    "git" = "source.toolkit.fluxcd.io/v1/gitrepositories";
    "helm" = "source.toolkit.fluxcd.io/v1/helmrepositories";
    "chart" = "source.toolkit.fluxcd.io/v1/helmcharts";
    "oci" = "source.toolkit.fluxcd.io/v1beta2/ocirepositories";
  };
  reconcile-plugins = lib.mapAttrs' reconcile flux-resources;
  toggle-suspend-plugins = lib.mapAttrs' toggle-suspend flux-resources;
  plugin = reconcile-plugins // toggle-suspend-plugins;
  views = lib.mergeAttrsList (map flux-view (lib.attrValues flux-resources));
in
{
  home.packages = with pkgs; [
    fluxcd
    kind
    kubectx
  ];

  tguimbert.apps.kubectl.enable = true;

  programs = {
    k9s = {
      enable = true;
      views = {
        inherit views;
      };
      inherit plugin;
    };
  };
}
