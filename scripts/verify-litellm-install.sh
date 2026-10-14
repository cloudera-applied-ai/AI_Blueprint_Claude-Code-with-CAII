#!/usr/bin/env bash
# verify-litellm-install.sh — fail the Docker build if LiteLLM proxy cannot import/start.
set -Eeuo pipefail

VENV="${1:-/opt/cai-claude/venv}"
PY="${VENV}/bin/python"
LITELLM="${VENV}/bin/litellm"

echo "=== Verifying LiteLLM proxy install ==="

"${PY}" - <<'PY'
import sys
from importlib.metadata import version

import fastapi
from packaging.version import Version

fastapi_version = Version(fastapi.__version__)
if fastapi_version >= Version("0.140"):
    raise SystemExit(f"FastAPI {fastapi.__version__} is too new; require <0.140")

# Import path that failed in production (proxy_server → management_v1 → fastapi).
from litellm.proxy import proxy_server  # noqa: F401

print(f"litellm {version('litellm')}")
print(f"fastapi {fastapi.__version__}")
print("proxy_server import OK")
PY

"${LITELLM}" --version

# Optional smoke-start (can be slow under QEMU/emulation during docker build on Apple Silicon).
if [[ "${SKIP_LITELLM_SMOKE:-0}" == "1" ]]; then
    echo "LiteLLM smoke test skipped (SKIP_LITELLM_SMOKE=1)"
    exit 0
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

cat >"${TMPDIR}/litellm-config.yaml" <<'YAML'
model_list:
  - model_name: claude-sonnet-4-6
    litellm_params:
      model: openai/test
      api_base: http://127.0.0.1:1
      api_key: test
litellm_settings:
  master_key: sk-build-verify
YAML

PORT=14000
LOG="${TMPDIR}/litellm.log"
: >"${LOG}"

"${LITELLM}" --config "${TMPDIR}/litellm-config.yaml" --host 127.0.0.1 --port "${PORT}" >>"${LOG}" 2>&1 &
PID=$!

for _ in $(seq 1 60); do
    if curl -sf --connect-timeout 1 --max-time 2 \
        -H "Authorization: Bearer sk-build-verify" \
        "http://127.0.0.1:${PORT}/health/liveliness" >/dev/null 2>&1 \
        || curl -sf --connect-timeout 1 --max-time 2 \
        "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
        kill "${PID}" 2>/dev/null || true
        wait "${PID}" 2>/dev/null || true
        echo "LiteLLM proxy smoke test OK"
        exit 0
    fi
    if ! kill -0 "${PID}" 2>/dev/null; then
        echo "LiteLLM proxy exited during smoke test. Log:" >&2
        tail -30 "${LOG}" >&2 || true
        exit 1
    fi
    sleep 0.5
done

kill "${PID}" 2>/dev/null || true
echo "LiteLLM proxy smoke test timed out. Log:" >&2
tail -30 "${LOG}" >&2 || true
exit 1
