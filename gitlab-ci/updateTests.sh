RELEASE_URL = "$1"
GH_DB_TOKEN = "$2"
CI_PROJECT_ID = "$3"
CI_MERGE_REQUEST_IID = "$4"

LAST_NON_BOT_COMMIT="$(git rev-list -1 --author='^(?!Diffblue CI).*$' --perl-regexp HEAD --no-merges)"
echo "Last non bot commit is $LAST_NON_BOT_COMMIT"
LAST_COMMIT="$(git rev-list HEAD -1 --no-merges)"
echo "Last commit is $LAST_COMMIT"
if [[ "$LAST_NON_BOT_COMMIT" == "$LAST_COMMIT" ]]
then
    python3 addComment.py --token $GH_DB_TOKEN --project_id $CI_PROJECT_ID --merge_request_id $CI_MERGE_REQUEST_IID --comment_id "<b><u>Diffblue Cover:</u></b> $(git show -s --format=%s)" --line_tag "<generate>" --message "<b>Test Generation Status:</b> Diffblue Cover is generating tests for this pull request :hourglass_flowing_sand:"
    mvn compile -B

    mkdir dcover
    cd dcover
    wget -c "$RELEASE_URL" -O dcover.zip -q
    unzip dcover.zip
    cd ..

    dcover/dcover create --batch --exclude io.diffblue.corebanking.ui.menu.ClientsMenu.executeMenuOption

    git add src/test/java
    python3 addComment.py --token $GH_DB_TOKEN --project_id $CI_PROJECT_ID --merge_request_id $CI_MERGE_REQUEST_IID --comment_id "<b><u>Diffblue Cover:</u></b> $(git show -s --format=%s)" --line_tag "<generate>" --message "<b>Test Generation Status:</b> Diffblue has pushed a commit to your PR with the updated unit tests :heavy_check_mark: <i>Please inspect the test diff to determine of the behaviour change is as expected</i>"
    if ! git diff --quiet --cached src/test/java 
    then 
        git commit -m "Update Diffblue Tests" 
        git push 
    else 
        python3 addComment.py --token $GH_DB_TOKEN --project_id $CI_PROJECT_ID --merge_request_id $CI_MERGE_REQUEST_IID --comment_id "<b><u>Diffblue Cover:</u></b> $(git show -s --format=%s)" --line_tag "<generate>" --message "<b>Test Generation Status:</b> Diffblue has finished analysing your pull request but deteced no changes :heavy_check_mark:"
        echo "Nothing to commit" 
    fi
else
    echo "Diffblue has already update this Merge Request"
fi

