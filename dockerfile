FROM node:20-bookworm-slim

# 1. Install System Chromium and graphical dependencies
#    NOTE: 'expect' has been removed — we no longer fight the CLI with expect scripts.
RUN apt-get update && apt-get install -y \
    bash git chromium \
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

# 3. Install Hermes CLI
RUN npm install -g hermes-cli

# 4. Pre-stage config into the EXACT path Hermes expects (SCAR TISSUE — DO NOT REMOVE)
#    The vsts ghost user breaks Node's home directory resolution.
#    run_sweep.sh sets HOME=/tmp/safe_home, so we pre-stage the config there.
#    Hermes looks for config at ~/.hermes/config.yaml (NOT ~/.config/hermes/).
#    This prevents Hermes from triggering its first-time setup wizard
#    ("? Name of the agency") which crashes in headless environments.
RUN mkdir -p /tmp/safe_home/.hermes && chmod -R 777 /tmp/safe_home
COPY config.yaml /tmp/safe_home/.hermes/config.yaml
RUN touch /tmp/safe_home/.hermes/.env && chmod 666 /tmp/safe_home/.hermes/.env

# Also keep a backup copy at the old location for resilience
RUN mkdir -p /opt/hermes && chmod 777 /opt/hermes
COPY config.yaml /opt/hermes/config.yaml
RUN chmod 666 /opt/hermes/config.yaml

# 5. Establish Workspace with Universal Permissions
WORKDIR /app
RUN mkdir -p /app/assets && touch /app/assets/banner.txt
COPY run_sweep.sh /app/run_sweep.sh
RUN chmod +x /app/run_sweep.sh && chmod -R 777 /app

ENTRYPOINT ["/bin/bash", "/app/run_sweep.sh"]