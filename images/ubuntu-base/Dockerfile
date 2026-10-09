# syntax=docker/dockerfile:1

FROM alpine AS fetcher

ARG TARGETARCH
ARG UBUNTU_RELEASE
ARG UBUNTU_VERSION

RUN --mount=type=bind,source=SHA256SUMS,target=/SHA256SUMS,ro \
    << 'EOF'
BASE="https://partner-images.canonical.com/oci/$UBUNTU_RELEASE/$UBUNTU_VERSION"
TARBALL="ubuntu-$UBUNTU_RELEASE-oci-$TARGETARCH-root.tar.gz"

cd "/tmp"
wget -qO "$TARBALL" "$BASE/$TARBALL" || exit 1
grep " \*$TARBALL\$" /SHA256SUMS | sha256sum -c - || exit 1

mkdir -p /rootfs
tar -xzf "$TARBALL" -C "/rootfs" || exit 1
rm "$TARBALL"
EOF

FROM scratch

ARG UBUNTU_VERSION

COPY --from=fetcher /rootfs /
