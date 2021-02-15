import os
import sys
import json
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--token', required=True)
parser.add_argument('--project_id', required=True)
parser.add_argument('--merge_request_id', required=True)
parser.add_argument('--comment_id', required=True)
parser.add_argument('--line_tag', required=True)
parser.add_argument('--message', required=True)
args = parser.parse_args()

token = args.token
project_id = args.project_id
merge_request_id = args.merge_request_id
comment_id = args.comment_id
line_tag = args.line_tag
message = args.message


default_comment = "<HEADER>" + comment_id
bot_username = "thomas.perkins"

def get_existing_comment_id():
	comment_id = -1
	comment_body = ""
	diffblue_comment_found = False
	os.system('curl -s ' + notes_url + ' --header "PRIVATE-TOKEN:' + token + '" > temp.json')
	with open("temp.json", "r") as read_file:
		data = json.load(read_file)
		for comment in data:
			if (comment["body"].startswith(default_comment) and comment["author"]["username"] == bot_username):
				comment_id = comment["id"]
				comment_body = comment["body"]

	os.system("rm temp.json")
	return comment_id, comment_body


notes_url = "https://gitlab.com/api/v4/projects/" + project_id + "/merge_requests" + "/" + merge_request_id + "/notes"
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
	os.system('curl -X POST \"' + notes_url + '\" --header \"PRIVATE-TOKEN:' + token + '\" --header "Content-Type: application/json" --data "{\\\"body\\\": \\\"' + new_message +'\\\"}"')
else:
	os.system('curl --request DELETE --header "PRIVATE-TOKEN:' + token + '" "' + notes_url + '/' + str(comment_id) + '"')
	os.system('curl -X POST \"' + notes_url + '\" --header \"PRIVATE-TOKEN:' + token + '\" --header "Content-Type: application/json" --data "{\\\"body\\\": \\\"' + new_message +'\\\"}"')

