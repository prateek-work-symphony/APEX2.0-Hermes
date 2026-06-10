FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y bash git && rm -rf /var/lib/apt/lists/*
RUN npm install -g hermes-cli
RUN mkdir -p /root/.hermes

COPY config.yaml /root/.hermes/config.yaml

WORKDIR /app
COPY run_sweep.sh /app/run_sweep.sh
RUN chmod +x /app/run_sweep.sh

ENTRYPOINT ["/bin/bash", "/app/run_sweep.sh"]