#!/bin/bash

# Jenkins runs this script from the workspace, not where the script is stored
. ./.jenkins/scripts/common.sh
if [ $? -ne 0 ]
then
  echo "[DIFFBLUE CI PIPELINE] Could not load the common file from $PWD"
  exit 1
fi

if [ -d "reports" ]
then
    if [ "$(ls -a reports)" ]
    then
        echoDiffblue "There are warnings and/or errors from running dcover and they will be concatenated and archived."
        for f in ./reports/**/.diffblue/reports/advisories*.txt
        do
            echo $f >> reports/all-advisories.txt
            cat $f >> reports/all-advisories.txt
            echo "" >> reports/all-advisories.txt
            echo "" >> reports/all-advisories.txt
        done
    else
        echoDiffblue "There are no warnings or errors from running dcover."
    fi
else
    echoDiffblue "There are no warnings or errors from running dcover."
fi