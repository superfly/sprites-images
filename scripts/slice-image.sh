#!/usr/bin/env sh

# Slices a span of layers out of an image into a new image, reusing their blobs.
#
# Usage: ./scripts/slice-image.sh LAYOUT PARENT CHILD

LAYOUT=$1 PARENT=$2 CHILD=$3

blob() {
    printf '%s/blobs/%s/%s\n' "$LAYOUT" "${1%%:*}" "${1#*:}"
}

put() {
    tmp=$(mktemp "$LAYOUT/blobs/sha256/.slice.XXXXXX") || exit
    printf '%s\n' "$1" > "$tmp" || exit
    digest=sha256:$(sha256sum "$tmp" | cut -d' ' -f1) || exit
    mv "$tmp" "$(blob "$digest")" || exit
    printf '%s %s\n' "$digest" "$(wc -c < "$(blob "$digest")")"
}

n=$(
    jq --slurpfile child "$(blob "$CHILD")" '
        .layers | map(.digest) as $parent
        | if ($child[0].layers[:($parent | length)] | map(.digest)) == $parent
          then $parent | length
          else error("parent layers are not a prefix of the child layers")
          end
    ' "$(blob "$PARENT")"
) || exit

config=$(jq -r '.config.digest' "$(blob "$CHILD")") || exit
config=$(
    jq -c --argjson n "$n" '
        .rootfs.diff_ids |= .[$n:]
        | .history |= (
            reduce .[] as $entry ({layers: 0, kept: []};
                (if .layers >= $n then .kept += [$entry] else . end)
                | .layers += (if $entry.empty_layer then 0 else 1 end))
            | .kept)
    ' "$(blob "$config")"
) || exit
config=$(put "$config") || exit

manifest=$(
    jq -c --argjson n "$n" --arg digest "${config% *}" --argjson size "${config#* }" '
        .layers |= .[$n:]
        | .config.digest = $digest
        | .config.size = $size
    ' "$(blob "$CHILD")"
) || exit
manifest=$(put "$manifest") || exit

echo "${manifest% *}"
