#!/usr/bin/env sh

# Determines which targets to rebuild given a list of changed files.
#
# Usage: git diff --name-only BASE HEAD | ./scripts/changed-targets.sh [GROUP]
#
# GROUP defaults to "default".

GROUP=${1:-default}
CHANGED=$(cat)

bake=$(docker buildx bake --print "$GROUP") || exit

printf '%s\n' "$bake" | jq -r --arg group "$GROUP" --arg changed "$CHANGED" '
    .group as $groups
    | .target as $targets
    | ($changed | split("\n") | map(select(. != ""))) as $changed
    | def members($g):
          $groups[$g].targets[] | if $groups[.] then members(.) else . end;
      def touched($dir):
          any($changed[]; . == $dir or startswith($dir + "/"));
      def dirs($t):
          $targets[$t].context,
          ($targets[$t].contexts // {} | .[] | select(test("^[a-z-]+:") | not));
      def deps($t):
          $targets[$t].contexts // {} | .[] | select(startswith("target:")) | ltrimstr("target:");
      def affected($t):
          any($changed[]; IN("docker-bake.hcl", "docker-bake.json"))
          or any(dirs($t); touched(.))
          or any(deps($t); affected(.));
    [members($group)] | unique[] | select(affected(.))
'
