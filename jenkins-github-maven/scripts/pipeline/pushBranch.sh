#!/bin/bash

# Pushes commits from HEAD_BRANCH into BASE_BRANCH. This assumes that HEAD_BRANCH is based on BASE_BRANCH
# This is used to cherry pick new commits from the temporary branch to the PR branch

SSH_KEY="$1"
HEAD_BRANCH="$2"
BASE_BRANCH="$3"

# Jenkins runs this script from the workspace, not where the script is stored
. ./.jenkins/scripts/common.sh
if [ $? -ne 0 ]
then
  echo "[DIFFBLUE CI PIPELINE] Could not load the common file from $PWD"
  exit 1
fi

echoDiffblue "\n\n\n***** pushBranch.sh"
echoDiffblue "arguments (3): SSH_KEY, $HEAD_BRANCH, $BASE_BRANCH"

checkoutBranch() {
  BRANCH="$1"

  echoDiffblue "\n\n\n***** checkoutBranch()"
  echoDiffblue "arguments (1): $BRANCH"
  git fetch origin "$BRANCH" -q
  git branch -D "$BRANCH" || true
  git checkout -b "$BRANCH" "origin/$BRANCH"
}

pushBranch() {
  HEAD_BRANCH="$1"
  echoDiffblue "\n\n\n***** pushBranch()"
  echoDiffblue "arguments (1): $HEAD_BRANCH"
  git push origin "$HEAD_BRANCH"
}

cherryPickFromSHAtoHEADToCheckedOutBranch() {
  echoDiffblue "\n\n\n***** cherryPickFromSHAtoHEADToCheckedOutBranch()"
  echoDiffblue "arguments (2): $SHA1, $SHA2"
  SHA1="$1"
  SHA2="$2"
  set +e
  git cherry-pick --quit # in case anything strange has happened and somehow a cherry-pick is lingering
  git cherry-pick "$SHA1..$SHA2"
  echo "Cherry-picked from $SHA1 to $SHA2"
}

remoteHostAuthentication "$SSH_KEY"
checkoutBranch "$HEAD_BRANCH"
checkoutBranch "$BASE_BRANCH"

echoDiffblue "\n\n\n***** Get Diffblue commits from $HEAD_BRANCH to $BASE_BRANCH"
SHA1="$(git rev-parse "$BASE_BRANCH")"
SHA2="$(git rev-parse "$HEAD_BRANCH")"
echoDiffblue "The shas to cherry pick from $HEAD_BRANCH to $BASE_BRANCH are $SHA1 to $SHA2"
if [ "$SHA1" != "$SHA2" ]
then
  cherryPickFromSHAtoHEADToCheckedOutBranch "$SHA1" "$SHA2"
else
  echoDiffblue "There are no diffblue tests."
fi

pushBranch "$BASE_BRANCH"