#!/bin/bash

# Copyright 2021-2022 Diffblue Limited. All Rights Reserved.
# Unpublished proprietary source code.
# Use is governed by https://docs.diffblue.com/licenses/eula

SSH_KEY="$1" # SSH key for remote host
BRANCH="$2" # Branch to delete


# Jenkins runs this script from the workspace, not where the script is stored
. ./.jenkins/scripts/common.sh
if [ $? -ne 0 ]
then
  echo "[DIFFBLUE CI PIPELINE] Could not load the common file from $PWD"
  exit 1
fi

echoDiffblue "\n\n\n***** deleteBranch.sh"
echoDiffblue "arguments (2): SSH_KEY, branch to delete: $BRANCH" # do not echo the SSH key

deleteBranch() {
  BRANCH="$1"

  echoDiffblue "\n\n\n***** deleteBranch()"
  echoDiffblue "arguments (1): branch to delete: $BRANCH"
  git fetch origin "$BRANCH" -q
  git branch -D "$BRANCH" -q || true
  set +e
  git push origin --delete "$BRANCH" -q
  if [ $? -eq 0 ]
  then
    echoDiffblue "$BRANCH was successfully deleted from remote"
  else
    echoDiffblue "$BRANCH was not deleted from remote because it was not there"
  fi
}

remoteHostAuthentication "$SSH_KEY"
deleteBranch "$BRANCH"