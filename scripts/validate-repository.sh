#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

expected_repo="https://github.com/alternatefutures/alternate-clouds-skills"

for manifest in .claude-plugin/marketplace.json .claude-plugin/plugin.json .cursor-plugin/plugin.json mcp.json; do
  jq -e . "$manifest" >/dev/null
done

bash -n install.sh
bash -n hooks/ensure-af-ready.sh

grep -Fq "$expected_repo" README.md
grep -Fq "$expected_repo" .claude-plugin/plugin.json
grep -Fq "$expected_repo" .cursor-plugin/plugin.json
grep -Fq 'GNU AFFERO GENERAL PUBLIC LICENSE' LICENSE

if grep -R -nE 'alternatefutures/alternate-skills|deploy-deck-app|Bundles the `ac` CLI' \
  README.md AGENTS.md .claude-plugin .cursor-plugin; then
  echo "stale repository or CLI references remain" >&2
  exit 1
fi

skill_count=0
for skill_file in skills/*/SKILL.md; do
  skill_name="$(basename "$(dirname "$skill_file")")"
  skill_count=$((skill_count + 1))

  grep -Eq '^name:[[:space:]]*'"$skill_name"'[[:space:]]*$' "$skill_file"
  grep -Eq '^description:[[:space:]]*[^[:space:]].*$' "$skill_file"
  grep -Fq '`'"$skill_name"'`' README.md
done

if [ "$skill_count" -ne 8 ]; then
  echo "expected 8 skill directories, found $skill_count" >&2
  exit 1
fi

echo "repository validation passed for $skill_count skills"
