#!/usr/bin/env bash
# Copyright 2026 Cloudfra
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Applies the GitHub repository settings this template expects, so they
# can be reproduced on any repo created from it (or restored here) with
# one command instead of clicking through Settings by hand.
#
# Usage: scripts/configure-github-repo.sh [OWNER/REPO]
# Defaults to the repo of the current directory's git remote. Requires
# `gh` to be authenticated with admin rights on the target repo.
#
# Safe to re-run: every step is idempotent. Settings that require a plan
# this repo doesn't have (e.g. branch protection or secret scanning on a
# private repo without GitHub Advanced Security) are best-effort - they
# print a warning and the script keeps going instead of failing outright,
# so the same script still works once the repo is public or the org
# upgrades.

set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

echo "Configuring $REPO"

# best_effort runs a command that may legitimately fail on some plans
# (branch protection, secret scanning, GHAS-only features on private
# repos) without aborting the rest of the script.
best_effort() {
  local description="$1"
  shift
  if ! "$@" >/dev/null; then
    echo "  (skipped) $description - not available for this repo/plan"
  fi
}

## Merge / branch hygiene ##

# Delete head branches once their PR merges, so stale branches don't pile up.
gh repo edit "$REPO" --delete-branch-on-merge

# Let a PR branch be updated from its base with a button click instead of a
# manual merge commit, so CI keeps testing against current main.
gh repo edit "$REPO" --allow-update-branch

# Merge a PR itself the moment its required checks pass, instead of relying
# on someone noticing and clicking merge. GitHub silently no-ops this one
# instead of erroring when the plan doesn't support it (private repos need
# Pro/Team/Enterprise), so check the result rather than trust the exit code.
gh repo edit "$REPO" --enable-auto-merge >/dev/null
if [[ "$(gh api "repos/$REPO" --jq .allow_auto_merge)" != "true" ]]; then
  echo "  (skipped) auto-merge - not available for this repo/plan"
fi

## Dependency / vulnerability management ##

# Dependabot alerts: flag dependencies with known vulnerabilities.
gh api --method PUT "repos/$REPO/vulnerability-alerts"

# Dependabot security updates: auto-PR fixes for the alerts above.
gh api --method PUT "repos/$REPO/automated-security-fixes"

# Private vulnerability reporting: lets someone report a vulnerability
# privately instead of filing a public issue.
best_effort "private vulnerability reporting" \
  gh api --method PUT "repos/$REPO/private-vulnerability-reporting"

## Secret scanning ##
# Free for public repos; on private repos it needs GitHub Advanced
# Security, which this doesn't enable automatically since it's a billed,
# org-level decision.

best_effort "secret scanning" \
  gh api --method PATCH "repos/$REPO" \
  -f "security_and_analysis[secret_scanning][status]=enabled"

best_effort "secret scanning push protection" \
  gh api --method PATCH "repos/$REPO" \
  -f "security_and_analysis[secret_scanning_push_protection][status]=enabled"

## Branch protection ##
# Classic branch protection needs GitHub Team/Enterprise for private
# repos (GitHub Free rejects it with a 403). Encodes the desired state
# so it takes effect the moment the repo goes public or the org upgrades.
# Required reviews are deliberately left out: this template is currently
# maintained solo, and requiring a second approver would just block
# merges rather than improve quality.
best_effort "branch protection on main" \
  gh api --method PUT "repos/$REPO/branches/main/protection" --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Build Linux",
      "Build Windows",
      "runner / misspell",
      "runner / hadolint",
      "runner / codespell"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null
}
EOF

echo "Done."
