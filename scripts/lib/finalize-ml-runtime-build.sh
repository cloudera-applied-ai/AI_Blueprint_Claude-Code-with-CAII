#!/usr/bin/env bash
# Sourced during image build: runtime ML metadata file + build log summary.
set -euo pipefail

CLAUDE_VERSION_FILE="${1:-/opt/cai-claude/claude-cli-version}"
HELPER="/opt/cai-claude/lib/ml-runtime-version-from-claude.sh"

# shellcheck disable=SC1090
eval "$("$HELPER" shell "$CLAUDE_VERSION_FILE")"

cat >/etc/profile.d/99-ml-runtime-metadata.sh <<EOF
# Claude Code CLI version captured at image build (catalog / session metadata)
export ML_RUNTIME_EDITION="Claude Code with CAI Inference"
export ML_RUNTIME_EDITOR="JupyterLab"
export ML_RUNTIME_SHORT_VERSION="${ML_RUNTIME_SHORT_VERSION}"
export ML_RUNTIME_MAINTENANCE_VERSION="${ML_RUNTIME_MAINTENANCE_VERSION}"
export ML_RUNTIME_FULL_VERSION="${ML_RUNTIME_FULL_VERSION}"
export ML_RUNTIME_DESCRIPTION="${ML_RUNTIME_DESCRIPTION}"
EOF
chmod 644 /etc/profile.d/99-ml-runtime-metadata.sh

printf '\n%s\n' '--- build result ---'
printf '%s\n' "${ML_RUNTIME_FULL_VERSION}"
printf '%s\n' "docker tag <image> <registry>/claudeworkbench:${ML_RUNTIME_FULL_VERSION}"
