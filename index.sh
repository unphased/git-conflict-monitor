#!/bin/bash

# configuration can be overridden by providing environment config file, e.g.:
# REPO=https://github.com/torvalds/linux
# TRUNK=develop
# SCRIPT='emailme.py <(echo "$@")'

file /opt/git-conflict-monitor-override.env | grep -q "ASCII text" && . /opt/git-conflict-monitor-override.env

# Recommend running this process in docker. This keeps things very simple. configure this script 
# with env vars via docker build args!

# Initial processing
# - Check if repo exists, clone and set up if not
if [ -z "$REPO" ]; then
  echo "No REPO defined in configuration, abort."
  exit 1
fi

REPO_NAME="${REPO##*/}"
GCM="/opt/git-conflict-monitor"
STORAGE_PATH="$GCM/repos"
REPO_METADATA_PATH="$GCM/metadata/$REPO_NAME"
REPO_RESULTS_PATH="$GCM/results/$REPO_NAME"
REPO_PATH="$STORAGE_PATH/$REPO_NAME"

echo "REPO_PATH: $REPO_PATH"

if [ ! -d "$REPO_PATH" ]; then
  mkdir -p "$STORAGE_PATH"
  pushd $STORAGE_PATH || exit 2
  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone "$REPO"
  popd || exit 2
  mkdir -p "$REPO_METADATA_PATH"
  touch "$REPO_METADATA_PATH/commit_reported_cache"
  mkdir -p "$REPO_RESULTS_PATH"
fi

while sleep 0.1; do
  # Periodic Processing
  # - only run logic on newly seen pairs of active commits

  cd "$REPO_PATH" || exit 2

  {
    git for-each-ref --sort=committerdate refs/remotes/ --format='%(committerdate:short) %(objectname) %(refname:short)'
    echo "$(date '+%Y-%m-%d' --date='4 days ago') FOUR_DAYS_AGO_GIT_CONFLICT_MONITOR_MARKER"
  } | sort | sed -e '1,/FOUR_DAYS_AGO_GIT_CONFLICT_MONITOR_MARKER/d' | cut -d ' ' -f2,3 |
    python3 -c 'from itertools import combinations
import fileinput
lines = (line.rstrip() for line in fileinput.input())
lines = ("{} {}".format(x, y) for x, y in combinations(lines, 2))
print(*lines, sep="\n")' | while read -r A_HASH A B_HASH B; do
      # check against our cache. only produce a report one time for each pair of commits.
      COMMIT_PAIR="$(echo "$A_HASH $B_HASH" | tr ' ' '\n' | sort | tr '\n' '_')"
      if ! grep -q "$COMMIT_PAIR" "$REPO_METADATA_PATH/commit_reported_cache"; then
        echo "Proceeding to check $B($B_HASH) merging into $A($A_HASH):"
        git checkout "$A_HASH"
        MERGEOUTPUT="$(git merge --no-commit --no-ff "$B_HASH" 2>&1)"
        MERGEABLE=$?
        echo "$(date) $COMMIT_PAIR ##### >>>$MERGEOUTPUT<<<" >> "$REPO_RESULTS_PATH/output"
        echo "$(date) $COMMIT_PAIR retcode >>>$MERGEABLE<<<" >> "$REPO_RESULTS_PATH/mergeable"
        echo "$(date) $COMMIT_PAIR ===== >>>$(git diff --cached)<<<" >> "$REPO_RESULTS_PATH/diff"
        echo "$COMMIT_PAIR" >> "$REPO_METADATA_PATH/commit_reported_cache"
        git merge --abort
      fi
    done
  sleep 10
done
