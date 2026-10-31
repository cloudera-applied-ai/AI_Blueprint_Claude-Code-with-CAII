#!/usr/bin/env bash
# Derive Cloudera ML runtime version fields from the installed Claude Code CLI semver.
# Used at image build time (Dockerfile metadata ARGs and finalize-ml-runtime-build.sh).

set -euo pipefail

read_claude_cli_version() {
  local input="${1:?}"
  if [[ -f "$input" ]]; then
    tr -d '[:space:]' <"$input"
  else
    printf '%s' "$input" | tr -d '[:space:]'
  fi
}

ml_runtime_from_claude_version() {
  local full
  full="$(read_claude_cli_version "$1")"
  if [[ ! "$full" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    echo "ml-runtime-version-from-claude: invalid semver: ${full}" >&2
    return 1
  fi
  ML_RUNTIME_FULL_VERSION="$full"
  ML_RUNTIME_SHORT_VERSION="${full%%.*}"
  ML_RUNTIME_MAINTENANCE_VERSION="${full#*.}"
  ML_RUNTIME_DESCRIPTION="Claude Code ${full} with CAI Inference on JupyterLab Runtime"
}

emit_shell() {
  ml_runtime_from_claude_version "$1"
  cat <<EOF
ML_RUNTIME_FULL_VERSION='${ML_RUNTIME_FULL_VERSION}'
ML_RUNTIME_SHORT_VERSION='${ML_RUNTIME_SHORT_VERSION}'
ML_RUNTIME_MAINTENANCE_VERSION='${ML_RUNTIME_MAINTENANCE_VERSION}'
ML_RUNTIME_DESCRIPTION='${ML_RUNTIME_DESCRIPTION}'
EOF
}

emit_build_args() {
  ml_runtime_from_claude_version "$1"
  printf '%s\n' \
    "--build-arg" "ML_RUNTIME_FULL_VERSION=${ML_RUNTIME_FULL_VERSION}" \
    "--build-arg" "ML_RUNTIME_SHORT_VERSION=${ML_RUNTIME_SHORT_VERSION}" \
    "--build-arg" "ML_RUNTIME_MAINTENANCE_VERSION=${ML_RUNTIME_MAINTENANCE_VERSION}" \
    "--build-arg" "ML_RUNTIME_DESCRIPTION=${ML_RUNTIME_DESCRIPTION}"
}

emit_labels() {
  ml_runtime_from_claude_version "$1"
  local edition="${ML_RUNTIME_EDITION:-Claude Code with CAI Inference}"
  local editor="${ML_RUNTIME_EDITOR:-JupyterLab}"
  printf '%s\n' \
    "--label" "com.cloudera.ml.runtime.edition=${edition}" \
    "--label" "com.cloudera.ml.runtime.full-version=${ML_RUNTIME_FULL_VERSION}" \
    "--label" "com.cloudera.ml.runtime.short-version=${ML_RUNTIME_SHORT_VERSION}" \
    "--label" "com.cloudera.ml.runtime.maintenance-version=${ML_RUNTIME_MAINTENANCE_VERSION}" \
    "--label" "com.cloudera.ml.runtime.description=${ML_RUNTIME_DESCRIPTION}" \
    "--label" "com.cloudera.ml.runtime.editor=${editor}" \
    "--label" "com.cloudera.ml.runtime.claude-cli-version=${ML_RUNTIME_FULL_VERSION}"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") shell|build-args|labels <version-or-file>
EOF
  exit 2
}

main() {
  [[ $# -ge 2 ]] || usage
  local mode="$1"
  shift
  case "$mode" in
    shell) emit_shell "$1" ;;
    build-args) emit_build_args "$1" ;;
    labels) emit_labels "$1" ;;
    *) usage ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
