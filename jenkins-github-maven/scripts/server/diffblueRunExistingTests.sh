#!/bin/bash

# Copyright 2021-2022 Diffblue Limited. All Rights Reserved.
# Unpublished proprietary source code.
# Use is governed by https://docs.diffblue.com/licenses/eula

# dcover location
RELEASE_URL="$1"
# project modules - note this must come last as it is var args
MODULES="$2"
# Dcover license key
DCOVER_LICENSE_KEY="$3"
# PR branch, e.g. feature/some-change
HEAD_BRANCH="$4"

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
getDcover "$RELEASE_URL" "$TOKEN" "$HEAD_BRANCH"
activateDcover "$DCOVER_LICENSE_KEY"
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