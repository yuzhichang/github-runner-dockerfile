#!/bin/bash

REPOSITORY=$REPO
ACCESS_TOKEN=$TOKEN
RUNNER_NAME=${HOST_HOSTNAME}-$(hostname)
WORK_DIRECTORY=${WORK_DIRECTORY_PREFIX}/${RUNNER_NAME}

echo "REPO ${REPOSITORY}"
echo "ACCESS_TOKEN ${ACCESS_TOKEN}"
echo "EXTRA_LABELS ${EXTRA_LABELS}"
echo "WORK_DIRECTORY ${WORK_DIRECTORY}"

# https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#create-a-registration-token-for-an-organization
# https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#create-a-registration-token-for-a-repository
#https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#delete-a-self-hosted-runner-from-an-organization
# https://docs.github.com/en/rest/actions/self-hosted-runners?apiVersion=2022-11-28#delete-a-self-hosted-runner-from-a-repository
if [[ "${REPOSITORY}" =~ / ]]; then
    ENTITY="repos/${REPOSITORY}"
else
    ENTITY="orgs/${REPOSITORY}"
fi
REG_TOKEN=$(curl -s -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/${ENTITY}/actions/runners/registration-token | jq .token --raw-output)

cd $HOME/actions-runner
sudo mkdir ${WORK_DIRECTORY} && sudo chown -R ${USER} ${WORK_DIRECTORY}

LABELS_OPT=${EXTRA_LABELS:+--labels $EXTRA_LABELS}
./config.sh --url https://github.com/${REPOSITORY} --token ${REG_TOKEN} --name ${RUNNER_NAME} ${LABELS_OPT} --work ${WORK_DIRECTORY}

cleanup() {
    echo "Removing runner..."
    REMOVE_TOKEN=$(curl -s -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/${ENTITY}/actions/runners/remove-token | jq .token --raw-output)
    ./config.sh remove --token ${REMOVE_TOKEN}
    sudo rm -rf ${WORK_DIRECTORY}
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
