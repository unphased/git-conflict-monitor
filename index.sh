#!/bin/bash

COLOR=$'\x1b[35m'
COLORSTRONG=$'\x1b[31m'
RESET=$'\x1b[m'

# helpers
execute () {
  CTR=1
  printf "$COLOR$(date)$RESET: "
  for arg in "$@"; do
    printf "\x1b[30m"'$'"%s=\x1b[33m%s\x1b[m " $CTR "$arg"
    (( CTR ++ ))
  done
  echo "" # new line
  "$@"
}

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

chown "$(whoami):$(whoami)" $STORAGE_PATH
echo "REPO_PATH: $REPO_PATH"

if [ ! -d "$REPO_PATH" ]; then
  mkdir -p "$STORAGE_PATH"
  pushd $STORAGE_PATH || exit 2
  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" execute git clone "$REPO"
  popd || exit 2
else
  echo "Repo $REPO_PATH already exists."
fi

mkdir -p "$REPO_METADATA_PATH"
touch "$REPO_METADATA_PATH/commit_reported_cache"
mkdir -p "$REPO_RESULTS_PATH"

while true; do
  # Periodic Processing
  # - only run logic on newly seen pairs of active commits

  cd "$REPO_PATH" || exit 2

  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git fetch

  {
    git for-each-ref --sort=committerdate refs/remotes/ --format='%(committerdate:short) %(objectname:short) %(refname:short)'
    echo "$(date '+%Y-%m-%d' --date='2 days ago') TWO_DAYS_AGO_GIT_CONFLICT_MONITOR_MARKER"
  } | sort | sed -e '1,/TWO_DAYS_AGO_GIT_CONFLICT_MONITOR_MARKER/d' | cut -d ' ' -f2,3 |
    python3 -c 'from itertools import combinations
import fileinput
lines = (line.rstrip() for line in fileinput.input())
lines = ("{} {}".format(x, y) for x, y in combinations(lines, 2))
print(*lines, sep="\n")' | while read -r A_HASH A B_HASH B; do
      # check against our cache. only produce a report one time for each pair of commits.
      COMMIT_PAIR="$(echo "$A_HASH $B_HASH" | tr ' ' '\n' | sort | tr '\n' '_')"
      if ! grep -q "$COMMIT_PAIR" "$REPO_METADATA_PATH/commit_reported_cache"; then
        # echo "Proceeding to check $B($B_HASH) merging into $A($A_HASH):"
        git checkout "$A_HASH"
        MERGEOUTPUT="$(git merge --no-commit --no-ff "$B_HASH" 2>&1)"
        MERGEABLE=$?
        echo "$COLOR$(date)$RESET $COMMIT_PAIR ##### >>>$MERGEOUTPUT<<<" >> "$REPO_RESULTS_PATH/output"
        if [ ! "$MERGEABLE" = 0 ]; then echo "$COLOR$(date) ${COLORSTRONG}FAILED TO MERGE $COMMIT_PAIR"; fi
        echo "$COLOR$(date)$RESET $COMMIT_PAIR retcode >>>$MERGEABLE<<<" >> "$REPO_RESULTS_PATH/mergeable"
        echo "$COLOR$(date)$RESET $COMMIT_PAIR ===== >>>$(git diff --cached)<<<" >> "$REPO_RESULTS_PATH/diffcached"
        echo "$COLOR$(date)$RESET $COMMIT_PAIR ----- >>>$(git diff)<<<" >> "$REPO_RESULTS_PATH/diff"
        execute git diff --cached --stat
        execute git diff --stat
        echo "$COMMIT_PAIR" >> "$REPO_METADATA_PATH/commit_reported_cache"
        if [ ! "$MERGEABLE" = "0" ]; then
          execute git merge --abort
        else
          execute git reset --hard HEAD
          execute git clean -fxd .
          execute git status
        fi
      fi
    done
  sleep 20
done
