#!/bin/bash

# This script is responsible for the logic and API interaction for the remote host comment
# This script example uses the Github API. Similar API calls will need to be substituted for other remote hosts.

# The script generates a comment that looks like, for example:
# <h2>:coffee: Diffblue CI is running existing Diffblue tests against your code changes.</h2><ul>
# <li>:white_check_mark: Run existing Diffblue tests against your code changes.</li>
# <li>:white_check_mark: Update Diffblue tests to reflect your code changes.</li></ul>
# The text in each line depends the result of the existing-diffblue-tests and update-diffblue-tests job
# which are reflected in the variables EXISTING_TESTS_STATUS and EXISTING_TESTS_STATUS

TOKEN="$1" # Token for API interaction with remote host
PR_NUMBER=$2
EXISTING_TESTS_STATUS="$3" # IN_PROGRESS, SUCCESS, FAILURE, UNSTABLE
EXISTING_TESTS_BUILD_URL="$4" # From Jenkins
UPDATING_TESTS_STATUS="$5" # IN_PROGRESS, COMPLETE, FAILURE
UPDATING_TESTS_BUILD_URL="$6" # From Jenkins
SSH_KEY="$7" # Remote host SSH key for fetching

# Jenkins runs this script from the workspace, not where the script is stored
. ./.jenkins/scripts/common.sh
if [ $? -ne 0 ]
then
  echo "[DIFFBLUE CI PIPELINE] Could not load the common file from $PWD"
  exit 1
fi

echoDiffblue "\n\n\n***** updateComment.sh"
echoDiffblue "arguments (7): TOKEN, $PR_NUMBER, $EXISTING_TESTS_STATUS, $EXISTING_TESTS_BUILD_URL, $UPDATING_TESTS_STATUS, $UPDATING_TESTS_BUILD_URL, SSH_KEY"

# This is used to tag the comment with a unique identifier to find it and delete/update, etc
DIFFBLUE_UNIQUE_COMMENT_ID="diffblue-update-tests-comment-id"

GITHUB_ORG="$(githubOrg)"
GITHUB_REPO="$(githubRepo)"
echoDiffblue "Commenting for org $GITHUB_ORG and repo $GITHUB_REPO"

remoteHostAuthentication "$SSH_KEY"
git fetch origin $CHANGE_TARGET -q
git fetch origin $CHANGE_BRANCH -q





####### Comment logic #######

getAnalysisComment() {
  COMMENT_ANALYSIS_RUNNING_EXISTING="<h2>:coffee: Diffblue CI is running existing Diffblue tests against your code changes.</h2><ul>"
  COMMENT_ANALYSIS_UPDATING="<h2>:coffee: Diffblue CI is analysing your code changes to update Diffblue tests.</h2><ul>"
  COMMENT_ANALYSIS_COMPLETE="<h2>:heavy_check_mark: Diffblue CI has analysed your code changes and is ready for your review.</h2><ul>"

  if [ "$EXISTING_TESTS_STATUS" == "IN_PROGRESS" ]
  then
    echo "$COMMENT_ANALYSIS_RUNNING_EXISTING"
  elif [ "$UPDATING_TESTS_STATUS" == "IN_PROGRESS" ]
  then
    echo "$COMMENT_ANALYSIS_UPDATING"
  else
    echo "$COMMENT_ANALYSIS_COMPLETE"
  fi
}

getExistingTestsComment() {
  COMMENT_EXISTING_TODO="<li>:white_check_mark: Run existing Diffblue tests against your code changes.</li>"
  COMMENT_EXISTING_DONE_FAILED="<li>:question: Existing Diffblue tests failed against your code changes. See the test report <a href=\"${EXISTING_TESTS_BUILD_URL}testReport/\">here</a> to check if these are expected failures or regressions. Note that any non-compiling tests have been removed and will not appear in the report.</li>"
  COMMENT_EXISTING_DONE_PASSED="<li>:heavy_check_mark: Existing Diffblue tests passed against your code changes. See the test report <a href=\"${EXISTING_TESTS_BUILD_URL}testReport/\">here</a>. Note that any non-compiling tests have been removed and will not appear in the report.</li>"

  if [ "$EXISTING_TESTS_STATUS" == "IN_PROGRESS" ]
  then
    echo "$COMMENT_EXISTING_TODO"
  elif [ "$EXISTING_TESTS_STATUS" == "SUCCESS" ]
  then
    echo "$COMMENT_EXISTING_DONE_PASSED"
  elif [ "$EXISTING_TESTS_STATUS" == "FAILURE" ] || [ "$EXISTING_TESTS_STATUS" == "UNSTABLE" ]
  then
    echo "$COMMENT_EXISTING_DONE_FAILED"
  else
    echo "Existing tests status $EXISTING_TESTS_STATUS is not considered in the script."
    exit 1
  fi
}

getUpdatingTestsComment() {
  COMMENT_UPDATED_TODO="<li>:white_check_mark: Update Diffblue tests to reflect your code changes.</li>"
  COMMENT_UPDATED_DONE_TESTS="<li>:heavy_check_mark: Diffblue has added commits to update the tests. Check that these reflect the intended behaviour of your code change before merging them. <a href=\"${UPDATING_TESTS_BUILD_URL}console/\">Build log</a></li>"
  COMMENT_UPDATED_DONE_NO_TESTS="<li>:heavy_check_mark: Diffblue did not update any tests. <a href=\"${UPDATING_TESTS_BUILD_URL}console/\">Build log</a></li>"
  COMMENT_UPDATED_DONE_FAILURE="<li>:x: Something went wrong. <a href=\"${UPDATING_TESTS_BUILD_URL}console/\">Build log</a></li>"

  GIT_AUTHOR_LIST=$(git log origin/$CHANGE_TARGET..origin/$CHANGE_BRANCH --pretty=%cn)
  if [ "$UPDATING_TESTS_STATUS" == "COMPLETE" ]
  then
    if [[ $GIT_AUTHOR_LIST = *"$(diffblueBotName)"* ]]
    then
      UPDATING_TESTS_STATUS="TESTS"
    else
      UPDATING_TESTS_STATUS="NO_TESTS"
    fi
  fi

  if [ "$UPDATING_TESTS_STATUS" == "IN_PROGRESS" ]
  then
    echo "$COMMENT_UPDATED_TODO"
  elif [ "$UPDATING_TESTS_STATUS" == "TESTS" ]
  then
    echo "$COMMENT_UPDATED_DONE_TESTS"
  elif [ "$UPDATING_TESTS_STATUS" == "NO_TESTS" ]
  then
    echo "$COMMENT_UPDATED_DONE_NO_TESTS"
  elif [ "$UPDATING_TESTS_STATUS" == "FAILURE" ]
  then
    echo "$COMMENT_UPDATED_DONE_FAILURE"
  else
    echo "Updating tests status $UPDATING_TESTS_STATUS is not considered in the script."
    exit 1
  fi
}

COMMENT_MESSAGE="$(getAnalysisComment)$(getExistingTestsComment)$(getUpdatingTestsComment)"




####### Comment API calls #######

echoDiffblue "Comment message: $COMMENT_MESSAGE"

# Appending unique comment in message to identify it later
COMMENT_MESSAGE="${COMMENT_MESSAGE} <!--${DIFFBLUE_UNIQUE_COMMENT_ID}-->"

echoDiffblue "Get Diffblue Update Tests Comment id"
COMMENT_NUMBER=$(curl \
  -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/issues/$PR_NUMBER/comments" \
  | jq --arg ID "$DIFFBLUE_UNIQUE_COMMENT_ID" \
  'map(select(.body | contains($ID)))[0].id')
echoDiffblue "Retrieved comment id $COMMENT_NUMBER"

if [ $COMMENT_NUMBER = null ]
then
  echoDiffblue "No existing comment found"
else
  echoDiffblue "Delete old comment"
  curl \
    -X DELETE \
    -H "Authorization: token $TOKEN" \
    "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/issues/comments/$COMMENT_NUMBER"
fi

JSON_BODY_STRING=$( jq -n \
                  --arg b "$COMMENT_MESSAGE" \
                  '{body: $b}' )

echoDiffblue "Add new comment with message $COMMENT_MESSAGE"
echoDiffblue "$COMMENT_MESSAGE"
curl \
  -X POST \
  -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/issues/$PR_NUMBER/comments" \
  -d "$JSON_BODY_STRING"
