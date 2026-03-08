#!/usr/bin/env bash
input=$(cat)

user=$(whoami)
dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir="${dir##*/}"

model=$(echo "$input" | jq -r '.model.display_name // ""')

# Git branch + status
work_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
branch=$(git -C "$work_dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || true)
git_dirty=""
if [ -n "$branch" ]; then
  # Check for uncommitted changes (staged + unstaged + untracked)
  if [ -n "$(git -C "$work_dir" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    git_dirty="dirty"
  fi
fi

# Context usage
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Powerline separator
SEP="▸"

# Colors using ANSI-C quoting (interpreted at assignment)
RST=$'\033[0m'
BOLD=$'\033[1m'
BLACK_FG=$'\033[30m'
WHITE_FG=$'\033[97m'

BG_GRAY=$'\033[48;5;238m'
BG_PURPLE=$'\033[48;5;141m'
BG_GREEN=$'\033[48;5;114m'
BG_YELLOW=$'\033[48;5;178m'
BG_BLUE=$'\033[48;5;67m'
BG_DARK=$'\033[48;5;236m'
BG_RED=$'\033[48;5;160m'

FG_GRAY=$'\033[38;5;238m'
FG_PURPLE=$'\033[38;5;141m'
FG_GREEN=$'\033[38;5;114m'
FG_YELLOW=$'\033[38;5;178m'
FG_BLUE=$'\033[38;5;67m'
FG_DARK=$'\033[38;5;236m'
FG_RED=$'\033[38;5;160m'

output=""

# Segment 1: user
output+="${BG_GRAY}${WHITE_FG}${BOLD} ${user} ${RST}"
# Separator 1→2
output+="${BG_PURPLE}${FG_GRAY}${SEP}${RST}"

# Segment 2: dir
output+="${BG_PURPLE}${BLACK_FG} ${dir} ${RST}"

if [ -n "$branch" ]; then
  if [ "$git_dirty" = "dirty" ]; then
    BG_BRANCH=$BG_YELLOW
    FG_BRANCH=$FG_YELLOW
  else
    BG_BRANCH=$BG_GREEN
    FG_BRANCH=$FG_GREEN
  fi
  output+="${BG_BRANCH}${FG_PURPLE}${SEP}${RST}"
  output+="${BG_BRANCH}${BLACK_FG} ${branch} ${RST}"
  output+="${BG_BLUE}${FG_BRANCH}${SEP}${RST}"
else
  output+="${BG_BLUE}${FG_PURPLE}${SEP}${RST}"
fi

# Segment 4: model
output+="${BG_BLUE}${WHITE_FG} ${model} ${RST}"

if [ -n "$used" ]; then
  if [ "$used" -ge 90 ] 2>/dev/null; then
    BG_CTX=$BG_RED
    FG_CTX=$FG_RED
  else
    BG_CTX=$BG_DARK
    FG_CTX=$FG_DARK
  fi
  output+="${BG_CTX}${FG_BLUE}${SEP}${RST}"
  output+="${BG_CTX}${WHITE_FG}${BOLD} ctx:${used}% ${RST}"
  output+="${FG_CTX}${SEP}${RST}"
else
  output+="${FG_BLUE}${SEP}${RST}"
fi

printf "%s" "$output"
