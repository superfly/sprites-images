# syntax=docker/dockerfile:1

FROM nixos/nix:2.35.2@sha256:7a007c766426c1877758ddc5cb87a965ac131fc78c582ce0083d922d51ae945c AS builder

RUN --mount=type=bind,target=/tmp/flake \
    << 'EOF'
set -e

system=$(
    nix --extra-experimental-features 'nix-command flakes' \
        build --no-link --print-out-paths --no-update-lock-file \
        '/tmp/flake#nixosConfigurations.nixos.config.system.build.toplevel'
)

nix-env --store /rootfs --extra-substituters 'auto?trusted=1' \
    -p /rootfs/nix/var/nix/profiles/system --set "$system"
mkdir -m 0755 -p /rootfs/etc/nixos /rootfs/sbin
touch /rootfs/etc/NIXOS
cp /tmp/flake/flake.lock /tmp/flake/*.nix /rootfs/etc/nixos/
ln -s /nix/var/nix/profiles/system/init /rootfs/sbin/init
EOF

FROM scratch

COPY --from=builder /rootfs /
