---
name: ship
description: "PR lifecycle automation: check/create PR, wait for confirmation, merge, delete branch, and clean up local+remote environment. Use when the user wants to ship changes, merge a PR, or says 'ship it', 'merge', 'manda pra develop', 'abre PR', 'fecha PR'."
---

# Ship — PR Lifecycle Automation

Automates the full PR lifecycle: verify branch -> check/create PR -> confirm -> merge -> cleanup.
Communicate in the user's language (follow the project's `communication_language` or conversation context).

## Step 0: Detect Project Conventions

Before anything else, infer the project's base branch and metadata from context:

### Base Branch Detection

Determine the default integration branch using this priority:
1. **CLAUDE.md** — look for explicit instructions like "PR always to `develop`" or "Main branch: main"
2. **Git config** — `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`
3. **Convention** — if both `main` and `develop` exist locally, prefer `develop` (feature-branch workflow)
4. **Fallback** — `main`

Store as `$BASE_BRANCH` for all subsequent steps.

### Project Name Detection

Detect the GitHub project name for `--project` flag:
1. **CLAUDE.md** — look for `--project "X"` or "Project: X"
2. **gh project list** — if exactly one project exists, use it
3. **Skip** — if ambiguous or none found, omit `--project` flag entirely

## Step 1: Validate Branch

```bash
git branch --show-current
```

- If on `main` or `develop` (or whatever `$BASE_BRANCH` is): **STOP**. Inform the user that direct work on integration branches is prohibited. Suggest creating a feature branch first.
- Otherwise: proceed with the current branch name.

## Step 2: Pre-flight Checks

### 2a. Uncommitted Changes

```bash
git status --porcelain
```

If there are uncommitted changes: **STOP**. Inform the user they have uncommitted work and suggest committing or stashing before shipping. Do NOT proceed — shipping with dirty working tree risks losing work.

### 2b. Sync Base Branch

Ensure the base branch is up-to-date to detect conflicts early:

```bash
git fetch origin $BASE_BRANCH
```

Check if the current branch can merge cleanly:
```bash
git merge-tree $(git merge-base HEAD origin/$BASE_BRANCH) HEAD origin/$BASE_BRANCH
```

If conflicts are detected: **WARN** the user listing the conflicting files. Suggest rebasing or merging `$BASE_BRANCH` into the current branch first. Ask if they want to proceed anyway or fix conflicts first.

## Step 3: Check for Open PR

```bash
gh pr list --head "$(git branch --show-current)" --state open --json number,title,url --jq '.[0]'
```

- **If PR exists**: display its number, title, and URL. Skip to Step 5 (Confirm).
- **If no PR**: proceed to Step 4.

## Step 4: Create PR

### 4a. Gather Context

Run these in parallel:
- `git diff $BASE_BRANCH...HEAD --stat` — summary of all changes vs base
- `git log $BASE_BRANCH..HEAD --oneline` — all commits that will be in the PR
- Check if branch is pushed: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`

If no commits ahead of `$BASE_BRANCH`: **STOP**. Nothing to ship.

If branch is not pushed, push it:
```bash
git push -u origin "$(git branch --show-current)"
```

### 4b. Analyze and Draft PR

Read the full diff (`git diff $BASE_BRANCH...HEAD`) and all commit messages to understand the changes holistically. Then draft:

- **Title**: concise, under 70 chars, following conventional commits (`feat:`, `fix:`, `chore:`, etc.)
- **Body**: use the project's PR template if `.github/pull_request_template.md` exists — fill in each section based on the actual changes. If no template, use:

```markdown
## Summary
<bullet points of what changed and why>

## Test plan
<how to verify the changes>

---
Generated with [Claude Code](https://claude.com/claude-code)
```

### 4c. Create the PR

Build the `gh pr create` command dynamically — only include flags that have values:

```bash
gh pr create \
  --base "$BASE_BRANCH" \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body content>
EOF
)" \
  --assignee "$(gh api user --jq '.login')"
```

Conditionally add:
- `--project "<name>"` — only if detected in Step 0
- `--label "<labels>"` — infer from context (e.g., `bug`, `feature`, `front-end`)
- `--milestone "<name>"` — only if a milestone matching the branch name exists (check with `gh api repos/{owner}/{repo}/milestones --jq '.[].title'`)

Display the PR URL to the user.

## Step 5: Confirm Before Merge

### 5a. Check CI Status

```bash
gh pr checks <number> --json name,state,conclusion --jq '.[] | select(.state != "COMPLETED" or .conclusion != "SUCCESS")'
```

- **All passed**: show green status
- **Pending**: warn that checks are still running — ask if user wants to wait or merge anyway
- **Failed**: warn with the failing check names — ask if user wants to merge anyway or fix first

### 5b. Ask for Confirmation

Present a summary:
- PR number, title, and URL
- Number of commits and files changed
- Target branch: `$BASE_BRANCH`
- CI status (passed/pending/failed)
- Merge strategy: merge commit (default)

Then **ask the user for explicit confirmation** before proceeding. Do NOT merge without approval.
Accept variations like: "sim", "yes", "ok", "go", "manda", "merge", "ship it".

If the user specifies a preference like "squash" or "rebase", use that strategy instead.

## Step 6: Merge and Cleanup

Once confirmed, save the current branch name before switching:

```bash
BRANCH_NAME=$(git branch --show-current)
```

Merge using the chosen strategy (default: `--merge`):
```bash
gh pr merge <number> --merge --delete-branch
# Or: gh pr merge <number> --squash --delete-branch
# Or: gh pr merge <number> --rebase --delete-branch
```

Clean up local environment:
```bash
# Switch to base branch and pull latest
git checkout $BASE_BRANCH && git pull origin $BASE_BRANCH

# Delete local branch (safe: already merged)
git branch -d "$BRANCH_NAME"

# Prune stale remote-tracking references
git fetch --prune
```

Report completion: merged PR URL, branches cleaned (local + remote), current branch is `$BASE_BRANCH`.

## Error Handling

- **Uncommitted changes**: STOP before any operations — user must commit or stash first
- **No commits ahead**: STOP — nothing to ship
- **Merge conflicts**: warn with file list, suggest rebase/merge, ask before proceeding
- **CI checks failing**: warn with check names, ask before proceeding
- **Branch not pushed**: auto-push before creating PR
- **Merge fails**: show error, do NOT clean up (branch still exists for debugging)
- **`git branch -d` fails**: branch may not be fully merged — show warning, suggest `-D` only if user confirms
