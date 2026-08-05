{ ... }:
{
  # Quality profiles as code. Everything else Sonarr and Radarr know lives in
  # their sqlite databases and survives only because ./backup.nix stages them;
  # this is the one part of their configuration that is declared here and
  # re-applied nightly from the TRaSH guides.
  #
  # The plain English profiles, deliberately, rather than the `french-*` ones
  # upstream also ships: they select clean original-audio releases from the
  # widest pool, which matters when a single backbone can be missing 82% of a
  # release's articles, and ./bazarr.nix supplies French subtitles afterwards.
  # 1080p and 2160p profiles are synced side by side and chosen per title —
  # ./jellyfin.nix can tone-map 4K HDR in fixed-function hardware.
  #
  # Profiles are referenced by **guide trash_id, not template name**: recyclarr 8
  # removed `include:` altogether (its v8 template branch ships an empty
  # `includes.json`), and an include now dies with "Unable to find include
  # template with name …" as though it were a typo. The ids below come from the
  # v8 starter templates of the same name.
  nixos.modules.recyclarr =
    {
      config,
      mkHeartbeat,
      ...
    }:
    let
      # `reset_unmatched_scores` is what makes the sync authoritative: scores the
      # guide does not set are reset rather than left at whatever the app had.
      profiles = map (trash_id: {
        inherit trash_id;
        reset_unmatched_scores.enabled = true;
      });
    in
    {
      services.recyclarr = {
        enable = true;
        configuration = {
          # Instance names must be unique across *both* services, as must
          # base_urls. Calling them both `main` is the obvious thing and fails
          # in the worst way available: recyclarr logs `Duplicate instances` at
          # debug level, syncs nothing and exits 0 — a green timer that never
          # updates anything.
          sonarr.sonarr-main = {
            base_url = "http://localhost:8989";
            # The same sops entry ./servarr.nix renders Sonarr's own environment
            # file from, not a second copy of the key.
            api_key._secret = config.sops.secrets.sonarrApiKey.path;
            # Sonarr's quality definitions are *global* — one set of size limits
            # for every profile — so `series` and `anime` cannot both be synced,
            # and live action is the majority. They differ only in the minimum
            # size: `series` floors Bluray-1080p at 50.4 MB/min against `anime`'s
            # 5, and a lot of anime lands under that. **If anime releases start
            # being rejected as too small, this is why**, and the fix is the one
            # word `anime` here.
            quality_definition.type = "series";
            quality_profiles = profiles [
              "72dae194fc92bf828f32cde7744e51a1" # WEB-1080p
              "d1498e7d189fbe6c7110ceaabb7473e6" # WEB-2160p
              # Its cutoff is Bluray 1080p despite the name, so it stops there
              # rather than chasing 20GB files. What it brings is anime-specific
              # custom-format scoring, which is per-profile and so unaffected by
              # the definition above.
              "20e0fc959f1f1704bed501f23bdae76f" # [Anime] Remux-1080p
            ];
            # The pair only makes sense together: the OLED does Dolby Vision, so
            # prefer it (+1000), but phones and browsers also play these files,
            # so reject the single-layer profile 5 releases that carry no HDR10
            # base layer (-10000) — those render green on anything without DV.
            # Profile 8.1 keeps both audiences happy from one file, which is
            # what "fallback" means here; nothing is downloaded twice.
            custom_format_groups.add = [
              { trash_id = "e0b2774083df4265f25c9e5bc6c80940"; } # [HDR Formats] DV Boost
              { trash_id = "d776a1ea912a117d66d83b880ff2055d"; } # [HDR Formats] DV (w/o HDR fallback)
            ];
          };
          radarr.radarr-main = {
            base_url = "http://localhost:7878";
            api_key._secret = config.sops.secrets.radarrApiKey.path;
            quality_definition.type = "movie";
            quality_profiles = profiles [
              "d1d67249d3890e49bc12e275d989a7e9" # HD Bluray + WEB
              "64fb5f9858489bdac2af690e27c8f42f" # UHD Bluray + WEB
            ];
            # Same pairing as Sonarr's, with Radarr's own ids for the groups.
            custom_format_groups.add = [
              { trash_id = "1616617ab3a14397a2b2321bcbda44d1"; } # [HDR Formats] DV Boost
              { trash_id = "7fc2751eef7e6bdc70b74136e5e35c76"; } # [HDR Formats] DV (w/o HDR fallback)
            ];
          };
        };
      };

      # Nothing breaks when a sync fails, but a sync that quietly stopped means
      # the profiles stop tracking the guides, which is otherwise invisible.
      systemd.services.recyclarr.serviceConfig = mkHeartbeat "recyclarr";

      # No `preservation` entry and nothing in ./backup.nix, on purpose:
      # /var/lib/recyclarr is the cloned guides plus a config.yml generated from
      # the attrset above, both rebuilt on the next run. Same argument
      # ./gatus.nix makes for its sqlite store, and it is why this user's uid is
      # left unpinned where every sibling has one.
    };
}
