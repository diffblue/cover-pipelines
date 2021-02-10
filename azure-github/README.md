# Azure and Github
This a simple example for how to run dcover in a pipeline on Corebanking with Azure pipelines and Github

## Configuration
2 secret variables will be needed to be added which are:
- `GH_DB_TOKEN` Which should a github access token with access to comment and push to your repo
- `RELEASE_URL` Which should be a url for a release of cover

The environment variable `COMMENT_SCRIPT_LOCATION` should also be configured to be the location where you place this python script if you decide to use this