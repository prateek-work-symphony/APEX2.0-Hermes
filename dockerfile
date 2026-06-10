FROM node:20-bookworm-slim

# Install Git, Bash, and Headless Chrome/Puppeteer dependencies
RUN apt-get update && apt-get install -y \
    bash git \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
    libxfixes3 libxrandr2 libgbm1 libasound2 \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g hermes-cli

# 🌟 Seed BOTH possible config locations to satisfy global package requirements
RUN mkdir -p /root/.hermes /root/.config/hermes
COPY config.yaml /root/.hermes/config.yaml
COPY config.yaml /root/.config/hermes/config.yaml

WORKDIR /app
COPY run_sweep.sh /app/run_sweep.sh
RUN chmod +x /app/run_sweep.sh

ENTRYPOINT ["/bin/bash", "/app/run_sweep.sh"]