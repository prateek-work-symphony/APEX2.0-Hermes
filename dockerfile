FROM node:20-bookworm-slim

# 1. Install Chrome graphical dependencies
RUN apt-get update && apt-get install -y \
    bash git \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 \
    libx11-xcb1 libxcb1 libxcursor1 libxi6 libxext6 libgtk-3-0 \
    libxss1 \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Hermes CLI globally (Must be done as root)
RUN npm install -g hermes-cli

# 🌟 3. THE V20 FIX: Switch to the non-root 'node' user. 
# This permanently disables the Chrome "Running as root" panic for ALL tools.
USER node

# 4. Setup internal workspace permissions for the node user
RUN mkdir -p /home/node/.hermes
COPY --chown=node:node config.yaml /home/node/.hermes/config.yaml

WORKDIR /home/node/app
COPY --chown=node:node run_sweep.sh /home/node/app/run_sweep.sh
RUN chmod +x /home/node/app/run_sweep.sh

ENTRYPOINT ["/bin/bash", "/home/node/app/run_sweep.sh"]