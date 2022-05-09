#!/bin/bash

####### dcover jars #######

# This should retrieve and unzip all of the scripts and jars required for dcover and echo
# the location of the dcover script. In this example, they are unzipped into the directory dcover.
# This should also set up the license if required, but that is not done here as it depends your
# your particular agreement with Diffblue.
# If you modify this, be sure to modify getDcoverScriptLocation to be correct.
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
