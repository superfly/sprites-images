#!/usr/bin/env sh

# Fetches the latest snapshot of the Ubuntu repositories and updates the
# package list with the snapshot's versions.
#
# Usage: ./scripts/update-ubuntu-packages.sh

PACKAGES_FILE=images/sprites-classic/devtools/packages.txt
SHA256SUMS_FILE=images/sprites-classic/devtools/SHA256SUMS
BAKE_FILE=docker-bake.hcl
VARS_FILE=docker-bake.json

if ! test -f "$PACKAGES_FILE"
then
    echo "error: $PACKAGES_FILE does not exist" >&2
    exit 1
fi

WORKDIR=$(mktemp -d "/tmp/ubuntu-packages-XXXXXX") || exit
trap 'rm -rf "$WORKDIR"' EXIT

SERIAL=$(jq -r '.variable.UBUNTU_VERSION.default // empty' "$VARS_FILE") || exit
if test -z "$SERIAL"
then
    echo "error: could not determine UBUNTU_VERSION" >&2
    exit 1
fi

# we don't know what time the build happens, so snapshot from the end of the
# day. Ubuntu's releases take a few days to hit mirrors, so this is probably
# safe.
SNAPSHOT=${SERIAL}T235959Z
if test "$SNAPSHOT" \> "$(date -u +%Y%m%dT%H%M%SZ)"
then
    echo "error: snapshot $SNAPSHOT is in the future" >&2
    exit 1
fi
EPOCH=$(
    jq -n --arg s "$SNAPSHOT" '$s | strptime("%Y%m%dT%H%M%SZ") | mktime'
) || exit

docker buildx bake \
    -f "$BAKE_FILE" -f "$VARS_FILE" -f - \
    --set "ubuntu-packages.no-cache=true" \
    --set "ubuntu-packages.context=$(dirname "$PACKAGES_FILE")" \
    --set "ubuntu-packages.args.SNAPSHOT=$SNAPSHOT" \
    --set "ubuntu-packages.output=type=local,dest=$WORKDIR" \
    ubuntu-packages << 'EOF' || exit
target "ubuntu-packages" {
  platforms       = ["linux/amd64"]
  contexts        = { ubuntu-base = "target:ubuntu-base" }
  dockerfile-inline = <<-DOCKERFILE
    # syntax=docker/dockerfile:1
    FROM ubuntu-base AS resolve
    ARG SNAPSHOT
    RUN --mount=type=bind,source=packages.txt,target=/packages.txt << 'SCRIPT'
    apt-get update && apt-get install -y ca-certificates || exit
    apt-get update --snapshot "$SNAPSHOT" || exit
    mkdir /out || exit
    cd /var/lib/apt/lists || exit
    sha256sum snapshot.ubuntu.com_ubuntu_"$SNAPSHOT"_dists_*_InRelease \
        > /out/SHA256SUMS || exit
    while IFS== read -r name _
    do
        candidate=$(
            apt-cache policy --snapshot "$SNAPSHOT" "$name" | grep 'Candidate:'
        )
        version=$${candidate#*: }
        if test -z "$version" || test "$version" = "(none)"
        then
            echo "error: no version found for $name" >&2
            exit 1
        fi
        echo "$name=$version"
    done < /packages.txt > /out/packages.txt
    SCRIPT

    FROM scratch
    COPY --from=resolve /out /
  DOCKERFILE
}
EOF

if cmp -s "$PACKAGES_FILE" "$WORKDIR/packages.txt" \
    && cmp -s "$SHA256SUMS_FILE" "$WORKDIR/SHA256SUMS"
then
    echo "$PACKAGES_FILE is up to date" >&2
else
    diff -u "$PACKAGES_FILE" "$WORKDIR/packages.txt" >&2
    cat "$WORKDIR/packages.txt" > "$PACKAGES_FILE"
    cat "$WORKDIR/SHA256SUMS" > "$SHA256SUMS_FILE"

    jq -S --arg v "$SNAPSHOT" --arg e "$EPOCH" '
        .variable.UBUNTU_SNAPSHOT.default = $v
        | .variable.SOURCE_DATE_EPOCH.default = $e
    ' "$VARS_FILE" > "$WORKDIR/vars.json" || exit
    cat "$WORKDIR/vars.json" > "$VARS_FILE"
    echo "Updated $PACKAGES_FILE, $SHA256SUMS_FILE, and $VARS_FILE" \
        "(UBUNTU_SNAPSHOT = $SNAPSHOT, SOURCE_DATE_EPOCH = $EPOCH)" >&2
fi
