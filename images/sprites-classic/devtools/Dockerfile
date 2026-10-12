# syntax=docker/dockerfile:1

FROM ubuntu-base AS base

# This should've been scoped to the RUN block, but fixing it would change some
# behaviors compared to the images we've already shipped.
ENV DEBIAN_FRONTEND=noninteractive

ARG UBUNTU_SNAPSHOT

# We intentionally leave /var/lib/apt in the image so users can install packages
# without running `apt update` first.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=bind,source=packages.txt,target=/packages.txt \
    --mount=type=bind,source=SHA256SUMS,target=/SHA256SUMS \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/cache/ldconfig \
    << 'EOF'
# The empty Ubuntu container doesn't have CA certificates, so HTTPS with the
# snapshots server fails. We can get away with skipping verification because
# the package lists are pinned to hashes.
set -- --snapshot "$UBUNTU_SNAPSHOT" -o Acquire::https::Verify-Peer=false
apt-get update "$@" || exit
(cd /var/lib/apt/lists && sha256sum -c --quiet /SHA256SUMS) || exit
xargs apt-get install -y --no-install-recommends "$@" < /packages.txt || exit

# Rewrite the snapshot as if it was a release. This gives almost the same
# experience as leaving behind a release from when the image was built,
# while being properly reproducible.
cd /var/lib/apt/lists || exit
for list in "snapshot.ubuntu.com_ubuntu_${UBUNTU_SNAPSHOT}_dists_"*
do
    case $list in
    *_dists_*-security_*) host=security.ubuntu.com ;;
    *) host=archive.ubuntu.com ;;
    esac
    mv "$list" "${host}_ubuntu_dists_${list#*_dists_}" || exit
done
cd / || exit

locale-gen en_US.UTF-8 || exit

useradd -m -s /bin/bash -u 1001 -G sudo,users sprite || exit
echo "sprite ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/sprite
chmod 440 /etc/sudoers.d/sprite
EOF

ENV LANG=en_US.UTF-8 \
    PATH="/.sprite/bin:$PATH"

COPY --chown=1001:1001 --chmod=u=rwX,go=rX home/sprite /home/sprite
