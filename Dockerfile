FROM ghcr.io/spacedriveapp/spacebot:full

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        gh \
        jq \
        nodejs \
        npm \
        openssh-client \
        python3 \
        python3-venv \
        rsync \
    && npm install -g opencode-ai \
    && rm -rf /var/lib/apt/lists/*

ENV SPACEBOT_DIR=/data
ENV HOME=/data/home
