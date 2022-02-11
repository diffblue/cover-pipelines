#!/bin/bash

# Configurables

######## Project #######

# The modules for Diffblue to analyse, space delimited
MODULES="auth-service account-service statistics-service notification-service"
modules() {
  echo "$MODULES"
}


####### Build commands for project #######

# Command for compiling Diffblue tests only - should do module only,
# e.g. mvn test-compile -P DiffblueTests -pl module1
commandToCompileTestsForSingleModule() {
  echo "mvn test-compile -P DiffblueTests -pl $MODULE"
}

# Command for running Diffblue tests only - will be called from within module internally in dcover, so don't include -pl,
# e.g. mvn test -P DiffblueTests
commandToRunAllDiffblueTests() {
  echo "mvn test -P DiffblueTests"
}

# This is for running the Diffblue tests - we don't want to see just the first failure, but all of them, so fail at the end
# e.g. mvn test -P DiffblueTests --fail-at-end
commandToRunAllDiffblueTestsFailingAtTheEnd() {
  echo "mvn test -P DiffblueTests --fail-at-end"
}

# Should build the project clean and fast, with all required jars,
# e.g. mvn clean install -DskipTests
commandToBuildProject() {
  echo "mvn clean install -DskipTests"
}


######## Remote host #######

# These match the name and email of the bot account set up on the repository for Diffblue.
# It should be a unique user because commits made by this bot affect logic in the Jenkinsfile.
# The token used to authenticate for Diffblue for git should also be from this user who needs write permissions.
COMMIT_BOT_NAME="db-ci-pipeline"
COMMIT_BOT_EMAIL="db-ci-pipeline@diffblue.com"
diffblueBotName() {
  echo $COMMIT_BOT_NAME
}
diffblueBotEmail() {
  echo $COMMIT_BOT_EMAIL
}

# This example uses github, and these are required for curl commands in updating comments.
GITHUB_ORG="diffblue"
GITHUB_REPO="piggymetrics"
githubOrg() {
  echo $GITHUB_ORG
}
githubRepo() {
  echo $GITHUB_REPO
}

# SSH authenication for remote host with Diffblue bot user
remoteHostAuthentication() {
    SSH_KEY=$1

    echoDiffblue "\n\n\n***** Remote host authentication"
    echoDiffblue "arguments (1): SSH_KEY" # dd not echo SSH key

    echoDiffblue "Git auth using SSH key stored in jenkins"
    eval "$(ssh-agent -s)"
    ssh-add $SSH_KEY
    git config user.name "$COMMIT_BOT_NAME"
    git config user.email "$COMMIT_BOT_EMAIL"

    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" --replace-all
}



####### dcover jars #######

# This should retrieve and unzip all of the scripts and jars required for dcover and echo the
# the location of the dcover script. In this example, they are unzipped into the directory dcover.
# This should also set up the license if required, but that is not done here as it depends your
# your particular agreement with Diffblue.
# In you modify this, be sure to modify getDcoverScriptLocation to be correct.
getDcover() {
  RELEASE_URL="$1"

  echoDiffblue "arguments (1): $RELEASE_URL"

  if [ -d dcover ]
  then
  	rm -rf dcover
  fi
  mkdir dcover
  cd dcover
  wget -c "$RELEASE_URL" -O dcover.zip -q
  unzip -o dcover.zip
  checkSuccess $?
  cd ..
}

# Must coordinate with getDcover, e.g. if the dcover jars are unzipped in dcover, then this is dcover/dcover
getDcoverScriptLocation() {
  echo "dcover/dcover"
}

# Depending on your license type and how you get the dcover jars, this may change. This example assumes an enterprise
# license and that the jars are installed freshly onto each VM each time, and thus need to be activated each time.
activateDcover() {
  LICENSE_KEY="$1"
  DCOVER_SCRIPT_LOCATION="$(getDcoverScriptLocation)"

  "$DCOVER_SCRIPT_LOCATION" activate "$LICENSE_KEY"
}



####### dcover configuration #######

# Where the patch file fed into Dcover is relative to root of project
patchFile() {
  echo "DiffblueTests.patch"
}

# The diffblue test location (relative to the module) specified in the profile DiffblueTests, e.g. src/diffbluetest/java
# This should be separate to the user tests
diffblueTestLocation() {
  echo "src/diffbluetest/java"
}

# The diffblue test classes location (relative to the module) specified in the profile DiffblueTests, e.g. target/diffblue-test-classes
# This should be separate to the user test classes
diffblueTestClassesLocation() {
  echo "target/diffblue-test-classes"
}




####### Diffblue script helpers #######

checkSuccess() {
  CODE=$1
  echoDiffblue "Check success: exit code is $CODE"
  if [ $CODE -ne 0 ]
  then
    echoDiffblue "The last command failed."
    exit 1
  fi
}

echoDiffblue() {
  MESSAGE="$1"
  echo "[DIFFBLUE CI PIPELINE] $MESSAGE"
}