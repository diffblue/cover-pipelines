import os
import sys
import json
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--token', required=True)
parser.add_argument('--pr_number', required=True)
parser.add_argument('--comment_id', required=True)
parser.add_argument('--line_tag', required=True)
parser.add_argument('--message', required=True)
args = parser.parse_args()

token = args.token
pr_number = args.pr_number
comment_id = args.comment_id
line_tag = args.line_tag
message = args.message


default_comment = "<HEADER>" + comment_id

def get_existing_comment_id():
	comment_id = -1
	comment_body = ""
	os.system('curl -s -H "Authorization: token ' + token + '" -H "Accept: application/vnd.github.groot-preview+json" https://api.github.com/repos/diffblue/demos-azure/issues/' + str(pr_number) + '/comments > temp.json')
	with open("temp.json", "r") as read_file:
		data = json.load(read_file)
		for comment in data:
			if comment["user"]["login"] == "db-ci-platform" and comment["body"].startswith(default_comment):
				comment_id = comment["id"]
				comment_body = comment["body"]

	os.system("rm temp.json")
	return comment_id, comment_body

comment_id, comment_body = get_existing_comment_id()


new_message = ""
if comment_body != "":
	lines = comment_body.split("<br>")
	line_edited = False
	for line in lines:
		if line.startswith(line_tag):
			line_edited = True
			line = line_tag + message
		if line != "":
			new_message += line + "<br>"
	if not line_edited:
		new_message += line_tag + message + "<br>"
else:
	new_message = default_comment + "<br>" + line_tag + message + "<br>"


if comment_id == -1:
	os.system('curl -s --location --request POST --header "Authorization: Bearer ' + token + '"  --header "Content-Type: application/json" https://api.github.com/repos/diffblue/demos-azure/issues/' + str(pr_number) + '/comments --data "{\\\"body\\\": \\\"' + new_message + '\\\"}"')
else:
	os.system('curl -s --location --request PATCH --header "Authorization: Bearer ' + token + '"  --header "Content-Type: application/json" https://api.github.com/repos/diffblue/demos-azure/issues/comments/' + str(comment_id) + ' --data "{\\\"body\\\": \\\"' + new_message + '\\\"}"')

