TriggerTagAndRelease() {
    changelogUpdated=$(git diff --name-only -- "${PARAM_CHANGELOG_FILE}")
    # Skip if there are changes in the changelog that have not been merged.
    if [ -n "${changelogUpdated}" ]; then
        echo "exiting, changes detected in the ${PARAM_CHANGELOG_FILE} file"
        exit 0
    fi

    hasTag=$(git show-ref --tags | grep "${CIRCLE_SHA1}" | grep "refs/tags/v\\?\\d\\.\\d\\.\\d")
    # Skip if this commit is already tagged.
    if [ -n "${hasTag}" ]; then
        echo "exiting, commit is already tagged: ${hasTag}"
        exit 0
    fi

    VCS_TYPE=$(echo "${CIRCLE_BUILD_URL}" | cut -d '/' -f 4)
    echo "{\"branch\": \"${PARAM_BRANCH}\", \"parameters\": ${PARAM_MAP}}" > pipelineparams.json
    cat pipelineparams.json
    DoCurl
    Result
}

DoCurl() {
    T=$(eval echo "$TOKEN")
    curl -u "${T}": -X POST --header "Content-Type: application/json" -d @pipelineparams.json \
      "${CIRCLECI_API_HOST}/api/v2/project/${VCS_TYPE}/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/pipeline" -o /tmp/curl-result.txt
}

Result() {
    CURL_RESULT=$(cat /tmp/curl-result.txt)
    if [[ $(echo "$CURL_RESULT" | jq -r .message) == "Not Found" || $(echo "$CURL_RESULT" | jq -r .message) == "Permission denied" || $(echo "$CURL_RESULT" | jq -r .message) == "Project not found" ]]; then
        echo "Was unable to trigger tag-and-release workflow. API response: $(jq -r .message < /tmp/curl-result.txt)"
        exit 1
    else
        echo "Pipeline triggered!"
        echo "${CIRCLECI_APP_HOST}/jobs/${VCS_TYPE}/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/$(jq -r .number < /tmp/curl-result.txt)"
    fi
}

# Will not run if sourced for bats-core tests.
# View src/tests for more information.
ORB_TEST_ENV="bats-core"
if [ "${0#*$ORB_TEST_ENV}" == "$0" ]; then
    TriggerTagAndRelease
fi
