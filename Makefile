run:
	mkdocs serve

build:
	mkdocs build

push:

push: AWS_PROFILE_NAME=oalfonso
push:
	aws --profile $(AWS_PROFILE_NAME) s3 cp site/ s3://oalfonso/ --recursive