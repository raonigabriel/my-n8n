# ─── Stage 1: Grab apk and its dependencies from a clean Alpine image ──────────
# This is necessary because n8n deliberately removed apk from their hardened image
# since v2.1.0. We copy the binaries rather than downloading them over the network.
FROM alpine:3.23 AS alpine-tools

# ─── Stage 2: Main image ────────────────────────────────────────────────────────
FROM n8nio/n8n:1.123.31

# Copy apk and its shared library dependencies from the Alpine stage
COPY --from=alpine-tools /sbin/apk /sbin/apk
COPY --from=alpine-tools /usr/lib/libapk.so* /usr/lib/
COPY --from=alpine-tools /lib/libssl.so* /lib/
COPY --from=alpine-tools /lib/libcrypto.so* /lib/
COPY --from=alpine-tools /lib/libz.so* /lib/

USER root

ARG TARGETPLATFORM

# ─── System packages ─────────────────────────────────────────────────────────────
# Note: no `apk upgrade` here — upgrading at build time breaks reproducibility.
# To get security patches, bump the base image version instead.
RUN apk add --no-cache \
    sudo shadow bash curl \
    gcompat libc6-compat libgcc libstdc++ ca-certificates pipx \
    docker-cli socat openssh-client unzip brotli zstd xz \
    ffmpeg imagemagick jq pigz zip libwebp-tools poppler-utils \
    exiftool pdfgrep tzdata ripgrep

# ─── System configuration (sudoers + docker group + timezone) ───────────────────
# sudo is scoped to /sbin/apk only — the node user needs passwordless apk access
# for runtime package installation from n8n workflows (no TTY available).
RUN echo "node ALL=(ALL) NOPASSWD: /sbin/apk" > /etc/sudoers.d/nopasswd && \
    chmod 0440 /etc/sudoers.d/nopasswd && \
    groupadd -g 999 docker 2>/dev/null || true && \
    usermod -aG docker node && \
    ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# ─── Node.js AI/utility libraries ───────────────────────────────────────────────
# Versions are intentionally unpinned here — Renovate Bot is configured to
# track these and open PRs when updates are available.
RUN npm install -g \
    @anthropic-ai/claude-code \
    @langchain/community @langchain/openai openai \
    youtube-transcript youtubei.js pdf-parse officeparser mammoth \
    @google/generative-ai @langchain/google-vertexai replicate \
    @mozilla/readability jsdom cheerio uuid hashids \
    tiktoken together-ai @fal-ai/client @supabase/supabase-js markdown-docx

USER node

# Make pipx-installed binaries available for the node user
ENV PATH="/home/node/.local/bin:${PATH}"

# ─── Python tooling ──────────────────────────────────────────────────────────────
RUN pipx install yt-dlp

# Smoke test — fails the build if yt-dlp is unreachable or PATH is misconfigured
RUN yt-dlp --version

# ─── Notes ───────────────────────────────────────────────────────────────────────
# SSH known_hosts is intentionally NOT baked into this image.
# Mount it at runtime instead so key rotations are handled automatically:
#
#   volumes:
#     - ~/.ssh/known_hosts:/home/node/.ssh/known_hosts:ro
#
# Also set the following in your n8n settings.json for Claude Code on Alpine:
#
#   {
#     "env": {
#       "USE_BUILTIN_RIPGREP": "0"
#     }
#   }
