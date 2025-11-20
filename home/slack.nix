{ pkgs, ... }:
{
  home = {
    packages = [
      (pkgs.slack.overrideAttrs (old: {
        installPhase = old.installPhase + ''
            rm $out/bin/slack

            makeWrapper $out/lib/slack/slack $out/bin/slack \
              --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]} \
              --add-flags "--ozone-platform=wayland --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer"

          # Fix slack screen sharing following: https://github.com/flathub/com.slack.Slack/issues/101#issuecomment-1807073763
            sed -i'.backup' -e 's/,"WebRTCPipeWireCapturer"/,"LebRTCPipeWireCapturer"/' $out/lib/slack/resources/app.asar
        '';
      }))
    ];

    persistence."/persistent/home/tguimbert" = {
      directories = [
        ".config/Slack"
      ];
    };
  };
}
