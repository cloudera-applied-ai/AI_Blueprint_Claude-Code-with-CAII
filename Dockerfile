# Cloudera ML runtime + Claude Code CLI → LiteLLM → Cloudera AI Inference (Devstral / vLLM)
FROM --platform=linux/amd64 docker.repository.cloudera.com/cloudera/cdsw/ml-runtime-pbj-jupyterlab-python3.13-standard:2026.08.1-b5

# ── System dependencies (agent tooling) ────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        vim nano \
        tmux screen \
        curl wget less tree jq unzip zip \
        ripgrep fd-find bat \
        netcat-openbsd dnsutils iputils-ping \
        pciutils htop procps lsof strace \
        ssh-client rsync socat ca-certificates git \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat

# ── Node.js 20 (required by Claude Code) ─────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# ── Claude Code CLI ──────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code \
    && command -v claude >/dev/null

# ── LiteLLM proxy (Anthropic API → OpenAI-compatible CAI Inference) ──────────
COPY requirements-litellm.txt /opt/cai-claude/requirements-litellm.txt
COPY scripts/verify-litellm-install.sh /opt/cai-claude/verify-litellm-install.sh
RUN chmod +x /opt/cai-claude/verify-litellm-install.sh && \
    python3 -m venv /opt/cai-claude/venv && \
    /opt/cai-claude/venv/bin/pip install --no-cache-dir --upgrade pip wheel packaging && \
    /opt/cai-claude/venv/bin/pip install --no-cache-dir -r /opt/cai-claude/requirements-litellm.txt && \
    SKIP_LITELLM_SMOKE=1 /opt/cai-claude/verify-litellm-install.sh /opt/cai-claude/venv

# ── ttyd: browser-based terminal (optional; CML may wire APP_PORT) ───────────
RUN TTYD_URL=$(curl -s https://api.github.com/repos/tsl0922/ttyd/releases/latest \
        | grep '"browser_download_url"' \
        | grep 'ttyd\.x86_64"' \
        | head -1 \
        | cut -d'"' -f4) && \
    curl -fsSL "$TTYD_URL" -o /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd

# ── Runtime directories ──────────────────────────────────────────────────────
RUN mkdir -p /home/cdsw/.claude/cai-inference /opt/cai-claude/lib && \
    chown -R cdsw:cdsw /home/cdsw/.claude

COPY scripts/lib/cai-common.sh /opt/cai-claude/lib/cai-common.sh
COPY scripts/cai-runtime-startup.sh /etc/profile.d/claude-caii.sh
RUN chmod +x /etc/profile.d/claude-caii.sh /opt/cai-claude/lib/cai-common.sh && \
    echo '[ -f /etc/profile.d/claude-caii.sh ] && source /etc/profile.d/claude-caii.sh' \
        >> /etc/bash.bashrc

# ── Default environment (override in CML project / session settings) ─────────
ENV CAI_HOME="/home/cdsw/.claude/cai-inference" \
    CAI_VENV_BIN="/opt/cai-claude/venv/bin" \
    CAII_OPENAI_BASE_URL="" \
    CAII_API_TOKEN="" \
    CAII_MODEL="" \
    CAII_LITELLM_PORT="${CAII_LITELLM_PORT:-4000}" \
    CAII_MAX_OUTPUT_TOKENS="8192" \
    CAII_MAX_INPUT_TOKENS="57344" \
    LITELLM_USE_CHAT_COMPLETIONS_URL_FOR_ANTHROPIC_MESSAGES="true" \
    APP_PORT="8080"

EXPOSE 8080
WORKDIR /home/cdsw

ENV ML_RUNTIME_EDITION="Claude Code with CAI Inference"
LABEL com.cloudera.ml.runtime.edition=$ML_RUNTIME_EDITION
