FROM node:20-alpine

# Install core dependencies required by the Azure Pipelines agent and git
RUN apk add --no-cache bash git coreutils shadow openssh-client

# CRITICAL: Tell Azure Pipelines exactly where to find Node inside this Alpine container
LABEL "com.azure.dev.pipelines.agent.handler.node.path"="/usr/local/bin/node"

# Install Hermes CLI globally inside the container
RUN npm install -g hermes-cli

# Setup the config folder layout for the headless root user
RUN mkdir -p /root/.hermes

# Bake your container-optimized config into the image
COPY config.yaml /root/.hermes/config.yaml

# Establish workspace
WORKDIR /app
COPY run_sweep.sh /app/run_sweep.sh
RUN chmod +x /app/run_sweep.sh

ENTRYPOINT ["/bin/bash", "/app/run_sweep.sh"]