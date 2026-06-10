FROM node:20-bookworm-slim

# 1. The FULL Graphical dependencies for Headless Chrome (No more crashes)
RUN apt-get update && apt-get install -y \
    bash git \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 \
    libx11-xcb1 libxcb1 libxcursor1 libxi6 libxext6 libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g hermes-cli
RUN mkdir -p /root/.hermes
COPY config.yaml /root/.hermes/config.yaml

WORKDIR /app
COPY run_sweep.sh /app/run_sweep.sh
RUN chmod +x /app/run_sweep.sh

ENTRYPOINT ["/bin/bash", "/app/run_sweep.sh"]