FROM n8nio/n8n:1.123.30

USER root

ARG TARGETPLATFORM

# Bootstrap apk package manager from upstream binaries via HTTP,
# auto-detecting architecture from the build target platform
RUN ARCH=$(case "$TARGETPLATFORM" in \
        "linux/amd64") echo "x86_64" ;; \
        "linux/arm64") echo "aarch64" ;; \
        *) echo "aarch64" ;; \
    esac) && \
    echo "Detected architecture: $ARCH" && \
    mkdir -p /tmp/apk-install && \
    cd /tmp/apk-install && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ARCH}/apk-tools-3.0.5-r0.apk && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ARCH}/libapk-3.0.5-r0.apk && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ARCH}/libcrypto3-3.5.5-r0.apk && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ARCH}/libssl3-3.5.5-r0.apk && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ARCH}/zlib-1.3.2-r0.apk && \
    wget -q http://dl-cdn.alpinelinux.org/alpine/v3.23/main/${ARCH}/ca-certificates-bundle-20251003-r0.apk && \
    tar -xzf libcrypto3-3.5.5-r0.apk && \
    cp -r usr/lib/* /lib/ 2>/dev/null || true && \
    cp -r etc/* /etc/ 2>/dev/null || true && \
    tar -xzf libssl3-3.5.5-r0.apk && \
    cp -r usr/lib/* /lib/ 2>/dev/null || true && \
    tar -xzf zlib-1.3.2-r0.apk && \
    cp -r usr/lib/* /lib/ 2>/dev/null || true && \
    tar -xzf ca-certificates-bundle-20251003-r0.apk && \
    cp -r etc/* /etc/ 2>/dev/null || true && \
    tar -xzf libapk-3.0.5-r0.apk && \
    cp -r usr/lib/* /lib/ 2>/dev/null || true && \
    cp -r lib/* /lib/ 2>/dev/null || true && \
    tar -xzf apk-tools-3.0.5-r0.apk && \
    cp -r sbin/apk /sbin/ && \
    cp -r lib/apk /lib/ 2>/dev/null || true && \
    cp -r lib/*.so* /lib/ 2>/dev/null || true && \
    cp -r var/cache/apk /var/cache/ 2>/dev/null || true && \
    cp -r etc/apk /etc/ 2>/dev/null || true && \
    ln -sf /sbin/apk /usr/bin/apk && \
    cd / && \
    rm -rf /tmp/apk-install && \
    apk upgrade --no-cache && \
    apk add --no-cache apk-tools && \
    apk add --no-cache \
    sudo shadow bash curl \
    gcompat libc6-compat libgcc libstdc++ ca-certificates pipx \
    docker-cli curl socat openssh-client unzip brotli zstd xz \
    ffmpeg imagemagick jq pigz zip libwebp-tools poppler-utils \
    exiftool pdfgrep tzdata

# Grant passwordless sudo to the "node" user
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd && \
    chmod 0440 /etc/sudoers.d/nopasswd

# Ensure the docker group exists with GID 999 and add "node" to it
RUN (getent group 999 | cut -d: -f1 || groupadd -g 999 docker) && \
    adduser node $(getent group 999 | cut -d: -f1) || true

# Set timezone to Sao Paulo
RUN ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# Install Node.js AI/utility libraries globally
RUN npm install -g @langchain/community @langchain/openai openai \
    youtube-transcript youtubei.js pdf-parse officeparser mammoth \
    @google/generative-ai @langchain/google-vertexai replicate \
    @mozilla/readability jsdom cheerio uuid hashids \
    tiktoken together-ai @fal-ai/client @supabase/supabase-js markdown-docx

USER node

# Make pipx-installed binaries available system-wide for the node user
ENV PATH="/home/node/.local/bin:${PATH}"

# Install yt-dlp for media downloading and audio/video processing
RUN pipx install yt-dlp

# Verify yt-dlp is reachable — fails the build if PATH is misconfigured
RUN yt-dlp --version

# Trust known SSH hosts for git operations
RUN mkdir -p /home/node/.ssh && \
    ssh-keyscan -H bitbucket.org > /home/node/.ssh/known_hosts && \
    ssh-keyscan -H gitlab.com >> /home/node/.ssh/known_hosts && \
    ssh-keyscan -H github.com >> /home/node/.ssh/known_hosts && \
    chmod 600 /home/node/.ssh/known_hosts
