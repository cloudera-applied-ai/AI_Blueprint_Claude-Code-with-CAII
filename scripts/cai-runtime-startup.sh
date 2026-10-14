#!/usr/bin/env bash
# /etc/profile.d/claude-caii.sh
#
# Sourced on every interactive JupyterLab terminal in the CAI Runtime image.
# Configures Claude Code to reach Cloudera AI Inference via a local LiteLLM proxy.
#
# Project environment variables (set in CML → Project → Settings → Advanced):
#
#   CAII_OPENAI_BASE_URL — OpenAI-compatible base URL including /v1
#                          (NIM: .../endpoints/<name>/v1 ; vLLM: .../openai/v1)
#   CAII_API_TOKEN       — Bearer token (CDP JWT); if unset, read access_token from /tmp/jwt
#   CAII_MODEL           — model id for chat/completions (GET /models or endpoint docs)
#   CAII_LITELLM_PORT    — optional local LiteLLM port (default: 4000)
#
# Commands:
#   claude-sync-config   — validate env, start/restart LiteLLM, write Claude settings
#   claude               — sync config then launch Claude Code
#   claude-status        — show env + proxy health
#   claude-stop-proxy    — stop background LiteLLM
#   claude-logs          — tail LiteLLM log

[[ $- != *i* ]] && return

export CAI_HOME="${CAI_HOME:-${HOME}/.claude/cai-inference}"
export CAI_VENV_BIN="${CAI_VENV_BIN:-/opt/cai-claude/venv/bin}"
export CAII_LITELLM_PORT="${CAII_LITELLM_PORT:-4000}"
export LITELLM_USE_CHAT_COMPLETIONS_URL_FOR_ANTHROPIC_MESSAGES="${LITELLM_USE_CHAT_COMPLETIONS_URL_FOR_ANTHROPIC_MESSAGES:-true}"

# shellcheck disable=SC1091
source /opt/cai-claude/lib/cai-common.sh

claude-sync-config() {
    cai_sync_config 1
}

claude() {
    cai_launch_claude "$@"
}

claude-status() {
    echo ""
    echo "┌─ Claude Code + Cloudera AI Inference ───────────────────────────────────┐"
    if cai_have_cmd claude; then
        echo "│  ✓ claude: $(command -v claude) ($(claude --version 2>/dev/null | head -1 || echo ''))"
    else
        echo "│  ✗ claude CLI not found"
    fi
    if cai_caii_env_ready; then
        echo "│  ✓ CAII env set (model: ${CAII_MODEL})"
        echo "│  ✓ base URL: ${CAII_OPENAI_BASE_URL}"
        if cai_proxy_health_ok; then
            echo "│  ✓ LiteLLM proxy: http://127.0.0.1:${CAII_LITELLM_PORT}"
        else
            echo "│  ○ LiteLLM proxy not running — run: claude-sync-config"
        fi
        echo "│  → Run: claude"
    else
        echo "│  ○ Set CAII_OPENAI_BASE_URL and CAII_MODEL"
        echo "│    Token: CAII_API_TOKEN or /tmp/jwt, then: claude-sync-config"
    fi
    echo "│  CAI_HOME=${CAI_HOME}"
    echo "│  Log: ${CAI_HOME}/litellm.log"
    echo "└──────────────────────────────────────────────────────────────────────────┘"
    echo ""
}

claude-stop-proxy() {
    cai_stop_proxy
    cai_log "Stopped LiteLLM proxy."
}

claude-logs() {
    tail -f "${CAI_HOME}/litellm.log"
}

_claude_banner() {
    claude-status
}

_claude_banner
