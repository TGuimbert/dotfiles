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

# Print the status line using printf to handle ANSI colors
# Colors: orange bg for user info, bright-yellow for dir, bright-cyan for repo, bright-blue for model/ctx
printf '\033[38;5;214m\033[1m  %s\033[0m' "$short_cwd"

if [ -n "$repo_seg" ]; then
  printf ' \033[38;5;87m%s\033[0m' "$repo_seg"
fi

if [ -n "$model_seg" ]; then
  printf ' \033[38;5;75m%s\033[0m' "$model_seg"
fi

if [ -n "$ctx_seg" ]; then
  printf ' \033[38;5;246m%s\033[0m' "$ctx_seg"
fi

if [ -n "$rate_seg" ]; then
  printf ' \033[38;5;246m%s\033[0m' "$rate_seg"
fi

if [ -n "$rate7_seg" ]; then
  printf ' \033[38;5;246m%s\033[0m' "$rate7_seg"
fi

printf '\n'
