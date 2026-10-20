# syntax=docker/dockerfile:1

FROM sprites-classic-agents

COPY --chmod=u=rwX,go=rX .sprite/ /.sprite/

RUN << 'EOF'
set -e

ln -sfn docs/agent-context.md /.sprite/llm.txt

mkdir -p /.sprite/etc/profile.d
cat >> /etc/profile << 'PROFILE'

# Source sprite environment
[ -r /.sprite/etc/profile.d/sprite.sh ] && . /.sprite/etc/profile.d/sprite.sh
PROFILE
EOF

ENV BROWSER="/.sprite/bin/sprite-browser" \
    HOME="/home/sprite" \
    PATH="/home/sprite/.local/bin:$PATH"

WORKDIR /home/sprite

USER sprite

ENTRYPOINT ["/.sprite/entrypoint.sh"]

CMD ["tail", "-f", "/dev/null"]
