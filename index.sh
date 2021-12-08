#!/bin/bash

# configuration is in environment variable format, e.g.:
# REPO=https://github.com/torvalds/linux
# TRUNK=develop

. /etc/git-conflict-monitor.env

# Recommend running this process in docker. This keeps things very simple and does not rely on 
# something like a systemd configuration, although that would be simple to set up as well.

# Initial processing
# - Check if repo exists, clone and set up if not
if [ -z "$REPO" ]; then
  echo "No REPO defined in configuration, abort."
  exit 1
fi

REPO_STORAGE_PATH=/etc/git-conflict-monitor-repos
REPO_PATH="$REPO_STORAGE_PATH/$REPO"

if [ ! -d "$REPO_PATH" ]; then
  mkdir -p "$REPO_STORAGE_PATH"
  pushd $REPO_STORAGE_PATH || exit 2
  git clone "$REPO"
  popd || exit 2
fi

while sleep 10; do
  # Periodic Processing
  # - Update stuff for the

  cd "$REPO_PATH" || exit 2
  git clone 
done
