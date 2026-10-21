# syntax=docker/dockerfile:1

FROM sprites-classic-devtools AS base
USER sprite
# Add ~/.local/bin to PATH so installers skip adding it to our .bashrc.
ENV PATH="/home/sprite/.local/bin:$PATH"

FROM sprites-classic-languages-node AS npm
USER sprite
ENV PATH="/home/sprite/.local/bin:/.sprite/languages/node/nvm/current/bin:$PATH"

# -- Antigravity

FROM base AS antigravity

# Google's CDN sometimes returns a compressed response even if we don't request
# it. Always request it so curl isn't confused.
RUN bash -o pipefail -c \
        'curl -fsSL --compressed https://antigravity.google/cli/install.sh | bash'

# -- Claude Code

FROM base AS claude

RUN bash -o pipefail -c \
        'curl -fsSL https://claude.ai/install.sh | bash -s latest' \
    && rm -rf ~/.claude/backups

# -- Codex

FROM base AS codex

RUN bash -o pipefail -c 'curl -fsSL https://chatgpt.com/codex/install.sh | sh' \
    && rm -rf ~/.codex/tmp

# -- GitHub Copilot

FROM base AS copilot

RUN bash -o pipefail -c 'curl -fsSL https://gh.io/copilot-install | bash'

# -- Cursor

FROM base AS cursor

RUN bash -o pipefail -c 'curl -fsSL https://cursor.com/install | bash'

# -- Gemini

FROM npm AS gemini

# Post-install hooks are restricted with --strict-allow-scripts. Gemini CLI
# is deprecated, so this list shouldn't change. npm requires ~/.local/lib for
# some reason.
RUN --mount=type=cache,target=/tmp/npm,uid=1001,gid=1001 \
    << 'EOF'
set -e

mkdir -p ~/.local/lib

export NPM_CONFIG_CACHE=/tmp/npm
export XDG_CACHE_HOME=/tmp/npm
npm install --global --prefix="$HOME/.local" --strict-allow-scripts \
    --allow-scripts=@github/keytar,node-pty @google/gemini-cli
EOF

# -- Grok

FROM base AS grok

# The installer only links into ~/.local/bin when it exists. It also creates a
# backup of .bashrc and links an `agent` alias that we reserve for Cursor.
RUN mkdir -p ~/.local/bin \
        && bash -o pipefail -c 'curl -fsSL https://x.ai/cli/install.sh | bash' \
        && rm ~/.bashrc.bak.* ~/.local/bin/agent

# -- Muse

FROM base AS muse

RUN bash -o pipefail -c 'curl -fsSL https://dev.meta.ai/install.sh | bash'

# -- Pi

FROM npm AS pi

# Pi's installer requires npm.
RUN --mount=type=cache,target=/tmp/npm,uid=1001,gid=1001 \
    NPM_CONFIG_CACHE=/tmp/npm \
        bash -o pipefail -c 'curl -fsSL https://pi.dev/install.sh | sh'

FROM base AS overlaps

USER root

RUN --mount=type=bind,from=antigravity,source=/home/sprite,target=/tmp/agents/antigravity \
    --mount=type=bind,from=claude,source=/home/sprite,target=/tmp/agents/claude \
    --mount=type=bind,from=codex,source=/home/sprite,target=/tmp/agents/codex \
    --mount=type=bind,from=copilot,source=/home/sprite,target=/tmp/agents/copilot \
    --mount=type=bind,from=cursor,source=/home/sprite,target=/tmp/agents/cursor \
    --mount=type=bind,from=gemini,source=/home/sprite,target=/tmp/agents/gemini \
    --mount=type=bind,from=grok,source=/home/sprite,target=/tmp/agents/grok \
    --mount=type=bind,from=muse,source=/home/sprite,target=/tmp/agents/muse \
    --mount=type=bind,from=pi,source=/home/sprite,target=/tmp/agents/pi \
    << 'EOF'
set -e

tab=$(printf '\t')
for dir in /tmp/agents/*
do
    agent=$(basename "$dir")

    # Besides .bashrc, .profile, and .zshrc (which we keep from base), there
    # shouldn't be any overlaps. We can't do this in the COPY statement, so we
    # force the check to happen in a separate step in BuildKit's build graph.
    rsync -ain --existing \
        --exclude=/.bashrc --exclude=/.profile --exclude=/.zshrc \
        "$dir/" /home/sprite/ \
        | grep -v '^\.d' | sed "s|^|$agent changed base file |" >> /tmp/errors
    rsync -ain --compare-dest=/home/sprite/ \
        --exclude=/.bashrc --exclude=/.profile --exclude=/.zshrc \
        "$dir/" /tmp/changes/ \
        | grep -v '^.d\|^created directory' | cut -c13- | sed "s|\$|$tab$agent|"
done | sort -t "$tab" -k1,1 > /tmp/overlaps

cut -f1 /tmp/overlaps | uniq -d | join -t "$tab" - /tmp/overlaps >> /tmp/errors
if test -s /tmp/errors
then
    echo "error: agents changed overlapping files:" >&2
    cat /tmp/errors >&2
    exit 1
fi
EOF

FROM sprites-classic-languages AS agents

COPY --from=antigravity --exclude=.bashrc --exclude=.profile --exclude=.zshrc \
    /home/sprite/ /home/sprite/
COPY --from=claude --exclude=.bashrc --exclude=.profile --exclude=.zshrc \
    /home/sprite/ /home/sprite/
COPY --from=codex --exclude=.bashrc --exclude=.profile --exclude=.zshrc \
    /home/sprite/ /home/sprite/
COPY --from=copilot --exclude=.bashrc --exclude=.profile --exclude=.zshrc \
    /home/sprite/ /home/sprite/
COPY --from=cursor --exclude=.bashrc --exclude=.profile --exclude=.zshrc \
    /home/sprite/ /home/sprite/
COPY --from=gemini --exclude=.bashrc --exclude=.profile --exclude=.zshrc \
    /home/sprite/ /home/sprite/
COPY --from=grok --exclude=.bashrc --exclude=.profile --exclude=.zshrc \
    /home/sprite/ /home/sprite/
COPY --from=muse --exclude=.bashrc --exclude=.profile --exclude=.zshrc \
    /home/sprite/ /home/sprite/
COPY --from=pi --exclude=.bashrc --exclude=.profile --exclude=.zshrc \
    /home/sprite/ /home/sprite/

USER sprite

# Agent skills are maintained once under .sprite-shared/skills and copied into
# each agent's skills directory. Some agents dislike symlinks and hardlinks
# make agent-specific modifications annoying, so we do full copies.
RUN --mount=type=bind,source=home/sprite,target=/tmp/home \
    --mount=type=bind,from=overlaps,source=/tmp/overlaps,target=/tmp/overlaps \
    << 'EOF'
set -e

cp -R /tmp/home/. /home/sprite/

for skills in .claude/skills .codex/skills .cursor/skills .gemini/skills \
              .copilot/skills .grok/skills .pi/agent/skills \
              .gemini/antigravity-cli/skills .config/muse/skills
do
    mkdir -p "/home/sprite/$skills"
    cp -R /tmp/home/.sprite-shared/skills/. "/home/sprite/$skills/"
done
EOF

USER root
