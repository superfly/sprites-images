#!/usr/bin/env sh

# Fetches the latest Ubuntu OCI rootfs serial from Canonical.
#
# Usage: ./scripts/update-ubuntu-rootfs.sh [RELEASE]
#
# RELEASE defaults to whatever UBUNTU_RELEASE is set to in docker-bake.json.

SHA256SUMS_FILE=images/ubuntu-base/SHA256SUMS
VARS_FILE=docker-bake.json
UBUNTU_PGP_FINGERPRINT=D2EB44626FDDC30B513D5BB71A5D6C4C7DB87C81

RELEASE="${1:-}"
if test -z "$RELEASE"
then
    RELEASE=$(jq -r '.variable.UBUNTU_RELEASE.default // empty' "$VARS_FILE")
fi
if test -z "$RELEASE"
then
  echo "error: could not determine UBUNTU_RELEASE" >&2
  exit 1
fi

BASE="https://partner-images.canonical.com/oci/$RELEASE"

echo "Fetching build info for $RELEASE..."
BUILD_INFO=$(curl -fsSL "$BASE/current/unpacked/build-info.txt") || exit

SERIAL=$(
    echo "$BUILD_INFO" | grep -i '^serial=' | cut -d= -f2 | tr -d '[:space:]'
)
if test -z "$SERIAL"
then
    echo "error: could not extract serial from build-info.txt" >&2
    echo "Content:" >&2
    echo "$BUILD_INFO" >&2
    exit 1
fi

echo "Current serial: $SERIAL"

echo "Fetching SHA256SUMS for serial $SERIAL..."
SHA256SUMS=$(curl -fsSL "$BASE/$SERIAL/SHA256SUMS") || exit

GNUPGHOME=$(mktemp -d "/tmp/ubuntu-keyring-XXXXXX") || exit
trap 'rm -rf "$GNUPGHOME"' EXIT

gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$UBUNTU_PGP_FINGERPRINT" \
    || exit
curl -fsSL "$BASE/$SERIAL/SHA256SUMS.gpg" -o "$GNUPGHOME/SHA256SUMS.gpg" || exit
echo "$SHA256SUMS" | gpg --verify "$GNUPGHOME/SHA256SUMS.gpg" - || exit

# sort the entries so diffs are easier to read
printf '%s\n' "$SHA256SUMS" | sort -k 2 > "$SHA256SUMS_FILE"
echo "Updated ubuntu-rootfs.sha256"

jq -S --arg v "$SERIAL" '.variable.UBUNTU_VERSION.default = $v' "$VARS_FILE" \
    > "$GNUPGHOME/vars.json" || exit
cat "$GNUPGHOME/vars.json" > "$VARS_FILE"
echo "Updated $VARS_FILE (UBUNTU_VERSION = $SERIAL)"
