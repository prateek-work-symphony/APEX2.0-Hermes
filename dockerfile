FROM node:20-bookworm-slim

# 1. Install System Chromium, graphical dependencies, and EXPECT
RUN apt-get update && apt-get install -y \
    bash git chromium expect \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 \
    libx11-xcb1 libxcb1 libxcursor1 libxi6 libxext6 libgtk-3-0 \
    libxss1 \
    && rm -rf /var/lib/apt/lists/*

# 2. Universal Chromium Sandbox Bypass
RUN mv /usr/bin/chromium /usr/bin/chromium-orig && \
    printf '#!/bin/bash\nexec /usr/bin/chromium-orig --no-sandbox "$@"\n' > /usr/bin/chromium && \
    chmod +x /usr/bin/chromium

# 3. Force ALL agent tools to use our safe system browser
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# 4. Install Hermes and setup the Public Config Folder
RUN npm install -g hermes-cli
RUN mkdir -p /opt/hermes && chmod 777 /opt/hermes
COPY config.yaml /opt/hermes/config.yaml
RUN chmod 666 /opt/hermes/config.yaml

# 5. Establish Workspace with Universal Permissions
WORKDIR /app
RUN mkdir -p /app/assets && touch /app/assets/banner.txt
COPY run_sweep.sh /app/run_sweep.sh
RUN chmod +x /app/run_sweep.sh && chmod -R 777 /app

ENTRYPOINT ["/bin/bash", "/app/run_sweep.sh"]