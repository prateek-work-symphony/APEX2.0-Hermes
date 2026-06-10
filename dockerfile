FROM node:20-bookworm-slim

# 1. Maintain the graphical dependencies for Headless Chrome
RUN apt-get update && apt-get install -y \
    bash git \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Hermes CLI globally
RUN npm install -g hermes-cli
RUN mkdir -p /root/.hermes
COPY config.yaml /root/.hermes/config.yaml

# 3. Establish the execution workspace
WORKDIR /app

# 🌟 THE FIX: Initialize the agency profile directly inside /app
RUN echo "" | hermes chat -z "init" > /dev/null 2>&1 || true

# 4. Copy and set permissions for the script
COPY run_sweep.sh /app/run_sweep.sh
RUN chmod +x /app/run_sweep.sh

ENTRYPOINT ["/bin/bash", "/app/run_sweep.sh"]