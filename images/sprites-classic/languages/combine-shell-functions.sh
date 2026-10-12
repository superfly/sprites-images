#!/usr/bin/env sh

# Combines individual shell function files into combined
# languages.{bash,zsh,fish} files.
#
# Usage: combine-shell-functions.sh <output_dir>
#
# This script expects function files to be in:
#   <output_dir>/functions/bash/*.bash
#   <output_dir>/functions/zsh/*.zsh
#   <output_dir>/functions/fish/*.fish
#
# And produces:
#   <output_dir>/languages.bash
#   <output_dir>/languages.zsh
#   <output_dir>/languages.fish

OUTPUT_DIR="${1:-/.sprite/languages/shells}"

for shell in bash zsh fish
do
    test -d "$OUTPUT_DIR/functions/$shell" || continue

    verb=unset
    if test "$shell" = fish
    then
        verb=erase
    fi

    {
        cat << EOF
# Auto-generated shell functions for language runtime activation
# These functions activate language runtimes on first use, then $verb themselves
# so subsequent calls use the real binaries directly.

EOF
        for file in "$OUTPUT_DIR/functions/$shell"/*."$shell"
        do
            test -f "$file" || continue
            cat "$file" || exit
            echo
        done
    } > "$OUTPUT_DIR/languages.$shell" || exit
done
