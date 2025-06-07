FROM n8nio/n8n:1.97.1

# Change use to root to install stuff
USER root

# Installs shell related tools
RUN apk add sudo shadow bash \
# Installs compatibility libs
    gcompat libc6-compat libgcc libstdc++ ca-certificates \
# Installs some basic tools
    docker-cli curl socat openssh-client unzip brotli zstd xz \
# Installs extra tools
    ffmpeg imagemagick jq pigz zip libwebp-tools poppler-utils pipx

# Allow sudo for user "node"
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd && \
    chmod 0440 /etc/sudoers.d/nopasswd

# Create the docker group if it doesn't exist
RUN EXISTING_GROUP=$(getent group 999 | cut -d: -f1) && \
    if [ -n "$EXISTING_GROUP" ]; then \
# Just add the user 'node' to the group
        adduser node "$EXISTING_GROUP"; \
    else \
# Create a new group then add the user 'node' to that group
        addgroup -g 999 docker && adduser node docker; \
    fi

# Set timezone
RUN ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime 

# Install some extra node packages
RUN npm install -g @langchain/community @langchain/openai openai \
    youtube-transcript youtubei.js pdf-parse officeparser mammoth \
    @google/generative-ai @langchain/google-vertexai replicate \
    @mozilla/readability jsdom ytdl-core cheerio uuid hashids \
    tiktoken together-ai @supabase/supabase-js

# Fall back user to "node"
USER node

# Install youtube-downloader
RUN pipx install yt-dlp && \
    pipx ensurepath

# Setup some SSH hosts
RUN mkdir -p /home/node/.ssh && \
    ssh-keyscan -H bitbucket.org > ~/.ssh/known_hosts && \
    ssh-keyscan -H gitlab.com >> ~/.ssh/known_hosts && \
    ssh-keyscan -H github.com >> ~/.ssh/known_host
