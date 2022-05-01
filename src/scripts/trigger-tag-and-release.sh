TriggerTagAndRelease() {
    hasTag=$(git show-ref "${CIRCLE_SHA1}" || echo "not found")
    # Skip if this commit is already tagged.
    if [ "${hasTag}" != "not found" ]; then
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
