FROM node:20-bookworm-slim

# 1. The FULL Graphical dependencies for Headless Chrome
RUN apt-get update && apt-get install -y \
    bash git \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 \
    libx11-xcb1 libxcb1 libxcursor1 libxi6 libxext6 libgtk-3-0 \
    libxss1 \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Hermes CLI globally
RUN npm install -g hermes-cli

# 🌟 3. THE V18 FIX: The Chrome Sandbox Bypass Wrapper
# This dynamically locates the Chrome executable downloaded by Puppeteer,
# renames it, and slots in a bash wrapper that forces the --no-sandbox flag.
RUN CHROME_PATH=$(find /usr/local/lib/node_modules/hermes-cli -path "*/puppeteer/.local-chromium/*/chrome-linux/chrome" -type f | head -n 1) && \
    mv "$CHROME_PATH" "$CHROME_PATH-orig" && \
    printf '#!/bin/bash\nexec "%s-orig" --no-sandbox "$@"\n' "$CHROME_PATH" > "$CHROME_PATH" && \
    chmod +x "$CHROME_PATH"

# 4. Establish Workspace
RUN mkdir -p /root/.hermes
COPY config.yaml /root/.hermes/config.yaml

WORKDIR /app
COPY run_sweep.sh /app/run_sweep.sh
RUN chmod +x /app/run_sweep.sh

ENTRYPOINT ["/bin/bash", "/app/run_sweep.sh"]