FROM n8nio/n8n:1.123.16

# Change user to root to install dependencies
USER root

# Installs shell related tools, compatibility libs, and basic tools
RUN apk add --no-cache \
    sudo shadow bash \
    gcompat libc6-compat libgcc libstdc++ ca-certificates pipx \
    docker-cli curl socat openssh-client unzip brotli zstd xz \
    ffmpeg imagemagick jq pigz zip libwebp-tools poppler-utils exiftool

# Allow sudo for user "node"
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd && \
    chmod 0440 /etc/sudoers.d/nopasswd

# Robust group handling for multi-arch compatibility
# Checks if group 999 or group 'docker' exists before creating/adding
RUN (getent group 999 | cut -d: -f1 || groupadd -g 999 docker) && \
    adduser node $(getent group 999 | cut -d: -f1) || true

# Set timezone
RUN ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime 

# Install extra node packages globally
RUN npm install -g @langchain/community @langchain/openai openai \
    youtube-transcript youtubei.js pdf-parse officeparser mammoth \
    @google/generative-ai @langchain/google-vertexai replicate \
    @mozilla/readability jsdom ytdl-core cheerio uuid hashids \
    tiktoken together-ai @fal-ai/client @supabase/supabase-js markdown-docx

# Switch back to "node" user
USER node

# Install youtube-downloader via pipx
RUN pipx install yt-dlp && \
    pipx ensurepath

# Setup SSH hosts for git operations
RUN mkdir -p /home/node/.ssh && \
    ssh-keyscan -H bitbucket.org > /home/node/.ssh/known_hosts && \
    ssh-keyscan -H gitlab.com >> /home/node/.ssh/known_hosts && \
    ssh-keyscan -H github.com >> /home/node/.ssh/known_hosts && \
    chmod 600 /home/node/.ssh/known_hosts
