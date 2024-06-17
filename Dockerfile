FROM alpine:3.20

# hadolint ignore=DL3018
RUN apk add --no-cache jq git openssh-client

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY update-tag.sh /update-tag.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/update-tag.sh"]
