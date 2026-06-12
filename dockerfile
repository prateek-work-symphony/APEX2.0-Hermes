FROM node:20-bookworm-slim

# 1. Install System Chromium, graphical dependencies, Python 3.11, and build tools
#    NOTE: Hermes is a PYTHON application (not an npm package).
#    We need python3, pip, git, and curl for the official installer.
RUN apt-get update && apt-get install -y \
    bash git curl python3 python3-venv python3-pip \
    chromium \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 \
    libx11-xcb1 libxcb1 libxcursor1 libxi6 libxext6 libgtk-3-0 \
    libxss1 \
    && rm -rf /var/lib/apt/lists/*

# 2. Universal Chromium Sandbox Bypass (SCAR TISSUE — DO NOT REMOVE)
#    Docker containers without SYS_ADMIN privileges crash Chrome with "No usable sandbox!"
#    This wrapper forces --no-sandbox on every Chromium invocation.
RUN mv /usr/bin/chromium /usr/bin/chromium-orig && \
    printf '#!/bin/bash\nexec /usr/bin/chromium-orig --no-sandbox "$@"\n' > /usr/bin/chromium && \
    chmod +x /usr/bin/chromium

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# 3. Install Hermes Agent via the official Nous Research installer
#    --skip-setup: skips the interactive setup wizard ("? Select provider", etc.)
#    --non-interactive: skips any prompts that require user input
#    --skip-browser: we already have system Chromium, don't install Playwright
#    The installer clones from GitHub and creates a Python venv.
#    Running as root on Linux, it installs to /usr/local/lib/hermes-agent
#    and links the command to /usr/local/bin/hermes.
ENV HERMES_HOME=/tmp/safe_home/.hermes
RUN mkdir -p /tmp/safe_home/.hermes && \
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | \
    bash -s -- --skip-setup --non-interactive --skip-browser --hermes-home /tmp/safe_home/.hermes

# 4. Pre-stage config into the EXACT path Hermes expects (SCAR TISSUE — DO NOT REMOVE)
#    Hermes looks for config at $HERMES_HOME/config.yaml (~/.hermes/config.yaml).
#    run_sweep.sh sets HOME=/tmp/safe_home, so HERMES_HOME resolves to
#    /tmp/safe_home/.hermes/config.yaml.
#    This prevents Hermes from triggering its first-time setup wizard
#    ("? Name of the agency") which crashes in headless environments.
COPY config.yaml /tmp/safe_home/.hermes/config.yaml
RUN touch /tmp/safe_home/.hermes/.env && chmod 666 /tmp/safe_home/.hermes/.env
RUN chmod -R 777 /tmp/safe_home

# Also keep a backup copy at /opt/hermes for resilience
RUN mkdir -p /opt/hermes && chmod 777 /opt/hermes
COPY config.yaml /opt/hermes/config.yaml
RUN chmod 666 /opt/hermes/config.yaml

# 5. Establish Workspace with Universal Permissions
WORKDIR /app
RUN mkdir -p /app/assets && touch /app/assets/banner.txt
COPY run_sweep.sh /app/run_sweep.sh
RUN chmod +x /app/run_sweep.sh && chmod -R 777 /app

ENTRYPOINT ["/bin/bash", "/app/run_sweep.sh"]