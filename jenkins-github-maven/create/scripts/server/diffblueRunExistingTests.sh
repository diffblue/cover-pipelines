#!/bin/bash

# dcover location
RELEASE_URL="$1"
# Dcover license key
UPDATE_TO_YOUR_DCOVER_LICENSE_KEY_CREDENTIALS_ID="$2"
# PR branch, e.g. feature/some-change
HEAD_BRANCH="$3"
# project modules
MODULES="$4"
# Modules MUST COME LAST. It is var args.

# Jenkins runs this script from the workspace, not where the script is stored
. ./.jenkins/scripts/common.sh
if [ $? -ne 0 ]
then
  echo "[DIFFBLUE CI PIPELINE] Could not load the common file from $PWD"
  exit 1
fi

# Extracting constants from common.sh
TEST_LOCATION="$(diffblueTestLocation)"
DCOVER_SCRIPT_LOCATION="$(getDcoverScriptLocation)"
echoDiffblue "Diffblue test location: $TEST_LOCATION, DCover script location: $DCOVER_SCRIPT_LOCATION"

# The project is built here to keep this simple. This could potentially be improved by building and exporting artifacts.
echoDiffblue "Build project"
eval "$(commandToBuildProject)"

echoDiffblue "Get dcover"
getDcover "$RELEASE_URL"
activateDcover "$UPDATE_TO_YOUR_DCOVER_LICENSE_KEY_CREDENTIALS_ID"
checkSuccess $?

echoDiffblue "Remove non-compiling tests in each module"
for MODULE in ${MODULES[@]}
do
  echoDiffblue "Compile tests"
  eval "$(commandToCompileTestsForSingleModule)"
  echoDiffblue "Removing non-compiling tests in $MODULE"
	"$DCOVER_SCRIPT_LOCATION" clean -d "$TEST_LOCATION" --working-directory "$MODULE"
  checkSuccess $?
done

# This must only fail at the end after all tests are run to be the most useful
echoDiffblue "Running Diffblue tests in base branch against your code changes"
eval "$(commandToRunAllDiffblueTestsFailingAtTheEnd)"
