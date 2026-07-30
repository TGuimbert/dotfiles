#!/usr/bin/env bash
# Claude Code status line — mirrors the starship gruvbox-rainbow prompt style

# Force C numeric locale so printf '%.0f' parses '12.4' regardless of the
# host locale's decimal separator (e.g. fr_FR uses ',').
export LC_ALL=C

input=$(cat)

# Extract fields from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
repo_owner=$(echo "$input" | jq -r '.workspace.repo.owner // empty')
repo_name=$(echo "$input" | jq -r '.workspace.repo.name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Build repo segment
repo_seg=""
if [ -n "$repo_owner" ] && [ -n "$repo_name" ]; then
  repo_seg=" ${repo_owner}/${repo_name}"
fi

# Build model segment (shorten to just the key name)
model_seg=""
if [ -n "$model" ]; then
  model_seg=" ${model}"
fi

# Build context usage segment
ctx_seg=""
if [ -n "$used_pct" ]; then
  ctx_int=$(printf '%.0f' "$used_pct")
  ctx_seg=" ctx:${ctx_int}%"
fi

# Build rate limit segments (Pro/Max only; each window may be absent)
rate_seg=""
if [ -n "$five_hour" ]; then
  five_int=$(printf '%.0f' "$five_hour")
  rate_seg=" 5h:${five_int}%"
fi

rate7_seg=""
if [ -n "$seven_day" ]; then
  seven_int=$(printf '%.0f' "$seven_day")
  rate7_seg=" 7d:${seven_int}%"
fi

# Shorten cwd: replace $HOME with ~
home_dir="$HOME"
short_cwd="${cwd/#$home_dir/\~}"

# Responsively truncate cwd to fit the terminal. Claude Code exports COLUMNS
# (v2.1.153+); fall back to 80 when unset. Reserve room for the right-hand
# segments (their plain ASCII width, the extra space printf prepends to each,
# and the leading icon/padding), then drop whole path components from the left
# (…/) until the path fits, hard-truncating as a last resort.
cols=${COLUMNS:-80}
strip_glyphs() {
  # Drop multibyte nerd-font glyphs so the remaining byte count ~= column width
  local s="${1//[![:print:]]/}"
  printf '%s' "$s"
}
right="$(strip_glyphs "$repo_seg$model_seg$ctx_seg$rate_seg$rate7_seg")"
nseg=0
for s in "$repo_seg" "$model_seg" "$ctx_seg" "$rate_seg" "$rate7_seg"; do
  [ -n "$s" ] && nseg=$((nseg + 1))
done
avail=$(( cols - ${#right} - nseg - 4 ))
[ "$avail" -lt 12 ] && avail=12

if [ "${#short_cwd}" -gt "$avail" ]; then
  IFS='/' read -ra parts <<< "$short_cwd"
  count=${#parts[@]}
  for ((k = count - 1; k >= 1; k--)); do
    candidate="…"
    for ((i = count - k; i < count; i++)); do
      candidate="$candidate/${parts[$i]}"
    done
    short_cwd="$candidate"
    [ "${#candidate}" -le "$avail" ] && break
  done
  # A single component still too long → hard character truncation
  if [ "${#short_cwd}" -gt "$avail" ]; then
    short_cwd="…${short_cwd: -$((avail - 1))}"
  fi
fi

# Colors. Default to fixed 256-color codes — used on hosts without noctalia
# (griffin) and during the brief window before noctalia first renders the
# theme. On noctalia hosts, pull the live colors from the rendered Noctalia
# custom theme (~/.config/claude/themes/noctalia.json) so the status line matches
# Claude Code's theme and follows its light/dark switches (noctalia re-renders on
# each mode change; the next status-line refresh reads the new hexes). Segments
# map to theme slots: dir→claude accent, repo→planMode, model→suggestion,
# ctx/rate meters→secondaryText.
esc=$'\033'
reset="${esc}[0m"
bold="${esc}[1m"
c_dir="${esc}[38;5;214m"
c_repo="${esc}[38;5;87m"
c_model="${esc}[38;5;75m"
c_muted="${esc}[38;5;246m"

theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/claude/themes/noctalia.json"
if [ -r "$theme_file" ]; then
  # #rrggbb -> truecolor SGR (empty on malformed input, so the default stands)
  hex2sgr() {
    local h="${1#\#}"
    [ "${#h}" -eq 6 ] || return 0
    printf '%s[38;2;%d;%d;%dm' "$esc" "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
  }
  if IFS=$'\t' read -r h_dir h_repo h_model h_muted \
    < <(jq -r '[.overrides.claude, .overrides.planMode, .overrides.suggestion, .overrides.secondaryText] | @tsv' "$theme_file" 2>/dev/null); then
    sgr=$(hex2sgr "$h_dir"); if [ -n "$sgr" ]; then c_dir="$sgr"; fi
    sgr=$(hex2sgr "$h_repo"); if [ -n "$sgr" ]; then c_repo="$sgr"; fi
    sgr=$(hex2sgr "$h_model"); if [ -n "$sgr" ]; then c_model="$sgr"; fi
    sgr=$(hex2sgr "$h_muted"); if [ -n "$sgr" ]; then c_muted="$sgr"; fi
  fi
fi

# Print the status line.
printf '%s%s  %s%s' "$c_dir" "$bold" "$short_cwd" "$reset"

if [ -n "$repo_seg" ]; then
  printf ' %s%s%s' "$c_repo" "$repo_seg" "$reset"
fi

if [ -n "$model_seg" ]; then
  printf ' %s%s%s' "$c_model" "$model_seg" "$reset"
fi

if [ -n "$ctx_seg" ]; then
  printf ' %s%s%s' "$c_muted" "$ctx_seg" "$reset"
fi

if [ -n "$rate_seg" ]; then
  printf ' %s%s%s' "$c_muted" "$rate_seg" "$reset"
fi

if [ -n "$rate7_seg" ]; then
  printf ' %s%s%s' "$c_muted" "$rate7_seg" "$reset"
fi

printf '\n'
