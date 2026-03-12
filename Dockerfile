FROM n8nio/n8n:1.123.24

# Change user to root to install dependencies
USER root

# Alpine architecture (x86_64 or aarch64) - defaults to aarch64, override at build time
ARG ALPINE_ARCH=aarch64

# Download packages using HTTP (busybox wget works without ssl_client for HTTP)
RUN mkdir -p /tmp/apk-install && \
    cd /tmp/apk-install && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ALPINE_ARCH}/apk-tools-3.0.5-r0.apk && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ALPINE_ARCH}/libapk-3.0.5-r0.apk && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ALPINE_ARCH}/libcrypto3-3.5.5-r0.apk && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ALPINE_ARCH}/libssl3-3.5.5-r0.apk && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ALPINE_ARCH}/zlib-1.3.2-r0.apk && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ALPINE_ARCH}/ca-certificates-bundle-20251003-r0.apk && \
    # Manually reinstall apk-tools and its dependencies from the downloaded packages
    cd /tmp/apk-install && \
    # Extract and install libcrypto3
    tar -xzf libcrypto3-3.5.5-r0.apk && \
    cp -r usr/lib/* /lib/ 2>/dev/null || true && \
    cp -r etc/* /etc/ 2>/dev/null || true && \
    # Extract and install libssl3
    tar -xzf libssl3-3.5.5-r0.apk && \
    cp -r usr/lib/* /lib/ 2>/dev/null || true && \
    # Extract and install zlib
    tar -xzf zlib-1.3.2-r0.apk && \
    cp -r usr/lib/* /lib/ 2>/dev/null || true && \
    # Extract and install ca-certificates-bundle
    tar -xzf ca-certificates-bundle-20251003-r0.apk && \
    cp -r etc/* /etc/ 2>/dev/null || true && \
    # Extract and install libapk
    tar -xzf libapk-3.0.5-r0.apk && \
    cp -r usr/lib/* /lib/ 2>/dev/null || true && \
    cp -r lib/* /lib/ 2>/dev/null || true && \
    # Extract and install apk-tools
    tar -xzf apk-tools-3.0.5-r0.apk && \
    cp -r sbin/apk /sbin/ && \
    cp -r lib/apk /lib/ 2>/dev/null || true && \
    cp -r lib/*.so* /lib/ 2>/dev/null || true && \
    cp -r var/cache/apk /var/cache/ 2>/dev/null || true && \
    cp -r etc/apk /etc/ 2>/dev/null || true && \
    # Create symlink for easier access
    ln -sf /sbin/apk /usr/bin/apk && \
    cd / && \
    rm -rf /tmp/apk-install && \
    # Upgrade packages
    apk upgrade --no-cache && \
    #  Reinstall apk-tools
    apk add --no-cache apk-tools && \
   # Installs shell related tools, compatibility libs, and basic tools
    apk add --no-cache \
    sudo shadow bash curl \
    gcompat libc6-compat libgcc libstdc++ ca-certificates pipx \
    docker-cli curl socat openssh-client unzip brotli zstd xz \
    ffmpeg imagemagick jq pigz zip libwebp-tools poppler-utils \
    exiftool pdfgrep

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
