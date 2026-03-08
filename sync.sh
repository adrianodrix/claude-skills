#!/bin/bash
# Sync Claude Code user-scope skills to this repo and push
# Usage: ./sync.sh [commit message]

set -e

SKILLS_DIR="$HOME/.claude/commands"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "Skills directory not found: $SKILLS_DIR"
  exit 1
fi

cd "$REPO_DIR"

# Copy all .md skill files except README
for file in "$SKILLS_DIR"/*.md; do
  [ -f "$file" ] && cp "$file" "$REPO_DIR/"
done

# Copy settings.json
[ -f "$HOME/.claude/settings.json" ] && cp "$HOME/.claude/settings.json" "$REPO_DIR/settings.json"

# Copy statusline script
[ -f "$HOME/.claude/statusline-command.sh" ] && cp "$HOME/.claude/statusline-command.sh" "$REPO_DIR/statusline-command.sh"

# Check if there are changes
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  echo "No changes to sync."
  exit 0
fi

# Show what changed
echo "Changes detected:"
git diff --stat
git ls-files --others --exclude-standard

# Commit and push
git add -A
MSG="${1:-"chore: sync skills from ~/.claude/commands"}"
git commit -m "$MSG

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push

echo "Synced and pushed successfully."
