run:
	mkdocs serve

build:
	rm site -rf | true
	mkdocs build

push: AWS_PROFILE_NAME=oalfonso
push: AWS_DISTRIBUTION_ID=E2G5BD3AT9ZMY4
push:
	aws --profile $(AWS_PROFILE_NAME) s3 rm s3://oalfonso/ --recursive
	aws --profile $(AWS_PROFILE_NAME) s3 cp site/ s3://oalfonso/ --recursive
	aws --profile $(AWS_PROFILE_NAME) cloudfront create-invalidation --distribution-id $(AWS_DISTRIBUTION_ID) --paths /*

deploy:
	make build
	make push