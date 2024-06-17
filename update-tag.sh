#!/usr/bin/env ash
# shellcheck shell=dash

ARG_REPOSITORY=
ARG_TAG=
ARG_SERVICE=
# ARG_SSH_KEY= # we get it from env

ARG_GIT_CONFIG_USERNAME="gitops-tag-updater"
ARG_GIT_CONFIG_EMAIL="no@reply.me"

##########################################
############## PARSE ARGS ################
##########################################

for i in "$@"; do
  case $i in
    --repository=*)
      ARG_REPOSITORY="${i#*=}"
      shift
      ;;

    --tag=*)
      ARG_TAG="${i#*=}"
      shift
      ;;

    --service=*)
      ARG_SERVICE="${i#*=}"
      shift
      ;;

    --git-config-username=*)
      ARG_GIT_CONFIG_USERNAME="${i#*=}"
      shift
      ;;

    --git-config-email=*)
      ARG_GIT_CONFIG_EMAIL="${i#*=}"
      shift
      ;;

    *)
      echo "Unknown option $i"
      exit 1
      ;;
  esac
done

if [ -z "$ARG_REPOSITORY" ]
then
  echo "--repository - invalid arg value"
  exit 1
fi

if [ -z "$ARG_TAG" ]
then
  echo "--tag - invalid arg value"
  exit 1
fi

if [ -z "$ARG_SERVICE" ]
then
  echo "--service - invalid arg value"
  exit 1
fi

if [ -z "$ARG_SSH_KEY" ]
then
  echo "ARG_SSH_KEY - not exists env variable "
  exit 1
fi

##########################################
####### WRITE ARG_SSH_KEY ON DISK ########
##########################################

TMP_DIR="$(mktemp -d)"
if [ -z "$?" ]
then
  echo "Failed to create TMP dir"
  exit 1
fi

SSH_KEY_PATH="$TMP_DIR/ssh-key"

if ! echo "$ARG_SSH_KEY" > "$SSH_KEY_PATH"
then
  echo "Failed to write ssh key on disk"
  rm -rf "$TMP_DIR"
  exit 1
fi

if ! chmod 400 "$SSH_KEY_PATH"
then
  rm -rf "$TMP_DIR"
  exit 1
fi


##########################################
########### CLONE REPOSITORY #############
##########################################

REPOSITORY_PATH="$TMP_DIR/gitops-repo"

export GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o IdentitiesOnly=yes -o StrictHostKeyChecking=no"

if ! git clone "$ARG_REPOSITORY" "$REPOSITORY_PATH"
then
  rm -rf "$TMP_DIR"
  exit 1
fi

##########################################
########## WRITE SERVICE FILE ############
##########################################

if ! mkdir -p "$REPOSITORY_PATH/services"
then
  echo "Failed to create 'service' dir"
  rm -rf "$TMP_DIR"
  exit 1
fi

SERVICE_FILE="$REPOSITORY_PATH/services/$ARG_SERVICE.json"

if ! jq -n --arg tag "$ARG_TAG" '{ tag: $tag }' > "$SERVICE_FILE"
then
  rm -rf "$TMP_DIR"
  exit 1
fi

##########################################
############## SETUP GIT #################
##########################################

if ! cd "$REPOSITORY_PATH"
then
  rm -rf "$TMP_DIR"
  exit 1
fi

if ! git config user.name "$ARG_GIT_CONFIG_USERNAME"
then
  rm -rf "$TMP_DIR"
  exit 1
fi

if ! git config user.email "$ARG_GIT_CONFIG_EMAIL"
then
  rm -rf "$TMP_DIR"
  exit 1
fi

##########################################
############ CHECK CHANGES ###############
##########################################

GIT_STATUS_OUT=$(git status --porcelain "$SERVICE_FILE")

if [ -z "$?" ]
then
  echo "git status failed - $STATUS_RESULT"
  rm -rf "$TMP_DIR"
  exit 1
fi

if [ -z "$GIT_STATUS_OUT" ]
then
  echo "Has no changes"
  rm -rf "$TMP_DIR"
  exit 0
fi

##########################################
############# PUSH CHANGES ###############
##########################################

if ! git add "$SERVICE_FILE"
then
  rm -rf "$TMP_DIR"
  exit 1
fi

if ! git commit -m "update $ARG_SERVICE.json"
then
  rm -rf "$TMP_DIR"
  exit 1
fi

if ! git push
then
  rm -rf "$TMP_DIR"
  exit 1
fi

rm -rf "$TMP_DIR"