#!/bin/bash

# dcover location
RELEASE_URL="$1"
# PR branch, e.g. feature/some-change
HEAD_BRANCH="$2"
# PR target branch, e.g. develop
BASE_BRANCH="$3"
# The private SSH key stored from Jenkinsfile
SSH_KEY=$4
# The module to generate tests for
MODULE="$5"
# Branch with unique name per PR to store the tests before merging into PR branch
TEMP_HEAD_BRANCH="$6"
# Dcover license key
UPDATE_TO_YOUR_DCOVER_LICENSE_KEY_CREDENTIALS_ID="$7"

# Jenkins runs this script from the workspace, not where the script is stored
. ./.jenkins/scripts/common.sh
if [ $? -ne 0 ]
then
  echo "[DIFFBLUE CI PIPELINE] Could not load the common file from $PWD"
  exit 1
fi

# Extracting constants from common.sh
PATCH_FILE="$(patchFile)"
TEST_LOCATION="$(diffblueTestLocation)"
TEST_CLASSES_LOCATION="$(diffblueTestClassesLocation)"
DCOVER_SCRIPT_LOCATION="$(getDcoverScriptLocation)"
VALIDATION_COMMAND="$(commandToRunAllDiffblueTests)"
echoDiffblue "Patch file location: $PATCH_FILE, Diffblue test location: $TEST_LOCATION, Diffblue test classes location: $TEST_CLASSES_LOCATION, DCover script location: $DCOVER_SCRIPT_LOCATION, Test validation command for dcover: $VALIDATION_COMMAND"

echoDiffblue "Running diffblueUpdateTests.sh"
echoDiffblue "with arguments (7): dcover url: $RELEASE_URL, head branch: $HEAD_BRANCH, base branch: $BASE_BRANCH, not echoing SSH_KEY arg, module: $MODULE, temp branch for storing tests: $TEMP_HEAD_BRANCH, not echoing license key" # don't echo the SSH_KEY or License key

# This deals with the possibility that the branch may have or may have not already been made by another job.
checkoutBranchWithFallback() {
  BRANCH="$1"
  FROM_BRANCH="$2" # fall back if BRANCH not on origin

  set +e
  echoDiffblue "running function checkoutBranchWithFallback()"
  echoDiffblue "arguments (2): $BRANCH, $FROM_BRANCH"
  git fetch origin "$BRANCH" -q
  if [ $? -eq 0 ] # might not be present on remote
  then
    echoDiffblue "git fetch origin $BRANCH -q worked and $BRANCH is present on remote"
    git branch -D "$BRANCH" -q || true # delete local copy if present
    git checkout -b "$BRANCH" "origin/$BRANCH" -q
  else
    echoDiffblue "git fetch origin $BRANCH -q failed and $BRANCH is not present on remote so we will checkout fresh copy from $FROM_BRANCH"
    git fetch origin "$FROM_BRANCH" -q
    git branch -D "$BRANCH" -q || true # delete local copy if present
    git checkout -b "$BRANCH" "origin/$FROM_BRANCH" -q
    git push -u origin "$BRANCH" -q || true # or true in case of creation race condition
  fi
  echoDiffblue "checkoutBranchWithFallback output:"
  git branch
  git log -1
}

makePatch() {
  BASE_BRANCH="$1"
  HEAD_BRANCH="$2"
  PATCH_FILE="$3"

  echoDiffblue "arguments (3): $BASE_BRANCH, $HEAD_BRANCH, $PATCH_FILE"

  git fetch origin "$BASE_BRANCH" -q
  git fetch origin "$HEAD_BRANCH" -q
  echoDiffblue "Running: git diff origin/$BASE_BRANCH...origin/$HEAD_BRANCH | tee $PATCH_FILE"
  git diff "origin/$BASE_BRANCH...origin/$HEAD_BRANCH" | tee "$PATCH_FILE"
  PATCH_FILE="$(realpath $PATCH_FILE)"
  echoDiffblue "makePatch output: $PATCH_FILE"
}

generateTestsAndCommit() {
  $BRANCH="$1"
  MODULE="$2"
  TEST_LOCATION="$3"
  TEST_CLASSES_LOCATION="$4"
  PATCH_FILE="$5"
  DCOVER_SCRIPT_LOCATION="$6"

  echoDiffblue "arguments (5): $BRANCH, $MODULE, $TEST_LOCATION, $PATCH_FILE, $DCOVER_SCRIPT_LOCATION"

  echoDiffblue "generateTestsAndCommit beginning state:"
  echoDiffblue "git branch:"
  git branch
  echoDiffblue "git log:"
  git log -1

  echoDiffblue "Git set up"
  git fetch origin "$BRANCH" -q

  # Note that all mvn commands here are run with a profile that only compiles/run Diffblue tests which are stored separately
  # 1) Run dcover validate to remove non-compiling and failing tests
  # 2) Call dcover with patch

  echoDiffblue "\n\n\n***** Generating tests for $MODULE on branch $BRANCH with test location $TEST_LOCATION, patch file $PATCH_FILE"
  # Note that all mvn command here are run with a profile that only compiles/run Diffblue tests which are stored separately

  echoDiffblue "what's in the module/src?"
  ls "$MODULE/src"
  echoDiffblue "what's in the module/target?"
  ls "$MODULE/target"

  if [ ! -d "$MODULE/$TEST_LOCATION" ]
  then
    echoDiffblue "Running dcover fresh on the project, i.e., without the patch file, because no Diffblue tests were found. This may take a while."
    mkdir -p "$MODULE/$TEST_LOCATION"
    "$DCOVER_SCRIPT_LOCATION" create --batch -x "$VALIDATION_COMMAND" -d "$TEST_LOCATION" --working-directory "$MODULE"
    checkSuccess $?
  elif [ -f "$PATCH_FILE" ]
  then
    echoDiffblue "Setting up dcover to run with patch file $PATCH_FILE"
    echoDiffblue "Running dcover validate to remove non-compiling tests and failing tests"
    "$DCOVER_SCRIPT_LOCATION" validate -d "$TEST_LOCATION" --working-directory "$MODULE" --validation-command "$VALIDATION_COMMAND"
    checkSuccess $?
    echoDiffblue "git diff after dcover validate"
    git diff
    echoDiffblue "Running dcover with patch file"
    "$DCOVER_SCRIPT_LOCATION" create --batch -x "$VALIDATION_COMMAND" -d "$TEST_LOCATION" --working-directory "$MODULE" --patch-only "$PATCH_FILE"
    checkSuccess $?
  else
    echoDiffblue "Aborting because the patch file at $PATCH_FILE does not appear to be a file"
    exit 1
  fi

  echoDiffblue "generateTestsAndCommit after generation state:"
  echoDiffblue "git diff"
  git diff "$MODULE/$TEST_LOCATION"
  echoDiffblue "\n\n\n***** Git add and commit"
  git add "$MODULE/$TEST_LOCATION"
  if ! git diff --quiet --cached "$MODULE/$TEST_LOCATION"
  then
    echoDiffblue "Fetch, rebase and commit to $BRANCH"
    git branch
    git fetch origin "$BRANCH" -q
    git stash # stash is here just in case the workspace was dirty for some reason, i.e., the workspace already contained test changes
    git rebase "origin/$BRANCH" # Assumes no merge conflicts possible because commits are restricted to modules
    git stash apply 0
    git add "$MODULE/$TEST_LOCATION"
    git commit -m "Update tests from DCover for $MODULE"
  else
    echoDiffblue "Nothing to commit"
  fi
}

pushBranch() {
  BRANCH="$1"
  echoDiffblue "arguments (1): $BRANCH"

  echoDiffblue "generateTestsAndCommit beginning state:"
  echoDiffblue "git branch:"
  git branch
  echoDiffblue "git log:"
  git log -1

  # try to push up to 5 times because other parallel jobs might be pushing too
  for i in 1 2 3 4 5
  do
     echoDiffblue "Fetching $BRANCH attempt $i"
     git fetch origin "$BRANCH"
     echoDiffblue "Rebasing $BRANCH attempt $i"
     git rebase "origin/$BRANCH" # Assumes no merge conflicts possible because commits are restricted to src/diffbluetest/java in modules
     echoDiffblue "Pushing $BRANCH attempt $i"
     git push origin "$BRANCH" # assumes remote branch is present already from checkout
     if [ $? -eq 0 ]
     then
       return
     else
       echoDiffblue "Something went wrong when pushing to $BRANCH, trying again"
     fi
  done
  echoDiffblue "Tried 5 times to push to $BRANCH and failed. Giving up."
  exit 1
}





remoteHostAuthentication "$SSH_KEY"
checkSuccess $?

checkoutBranchWithFallback "$TEMP_HEAD_BRANCH" "$HEAD_BRANCH"
checkSuccess $?

getDcover "$RELEASE_URL"
activateDcover "$UPDATE_TO_YOUR_DCOVER_LICENSE_KEY_CREDENTIALS_ID"
checkSuccess $?

# The project is built here to keep this simple. This could potentially be improved by building and exporting artifacts.
echoDiffblue "Build project"
eval "$(commandToBuildProject)"

echoDiffblue "\n\n\n***** Generating patch file between $BASE_BRANCH and $HEAD_BRANCH with patch file at realpath of $PATCH_FILE"
makePatch "$BASE_BRANCH" "$HEAD_BRANCH" "$PATCH_FILE"
checkSuccess $?

echoDiffblue "\n\n\n***** Generating tests for $MODULE"
generateTestsAndCommit "$TEMP_HEAD_BRANCH" "$MODULE" "$TEST_LOCATION" "$TEST_CLASSES_LOCATION" "$PATCH_FILE" "$DCOVER_SCRIPT_LOCATION"
checkSuccess $?

echoDiffblue "\n\n\n***** Pushing to $TEMP_HEAD_BRANCH for $MODULE"
pushBranch "$TEMP_HEAD_BRANCH"
checkSuccess $?
