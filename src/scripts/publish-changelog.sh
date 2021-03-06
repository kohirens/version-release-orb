MergeChangelog() {
    prevCommit=$(git rev-parse origin/"${PARAM_BRANCH}")

    # make the file so that the persist step does not fail.
    echo "" > "${PARAM_COMMIT_FILE}"

    changelogUpdated=$(git diff --name-only -- "${PARAM_CHANGELOG_FILE}")
    changelogUntracked=$(git status | grep "${PARAM_CHANGELOG_FILE}" || echo "")
    if [ "${changelogUntracked}" != "" ]; then
        echo "detected updated to the ${PARAM_CHANGELOG_FILE} file"
    elif [ -z "${changelogUpdated}" ]; then
        echo "no changes detected in the ${PARAM_CHANGELOG_FILE} file"
        exit 0
    fi

    # Exit if branch exist remotely already.
    GEN_BRANCH_NAME="auto-update-changelog"
    branchExistRemotely=$(git ls-remote --heads "${CIRCLE_REPOSITORY_URL}" "${GEN_BRANCH_NAME}" | wc -l)
    echo "branchExistRemotely = ${branchExistRemotely}"
    # Exit if branch exist remotely already.
    if [ "${branchExistRemotely}" = "1"  ]; then
        echo "the branch '${GEN_BRANCH_NAME}' exists on ${CIRCLE_REPOSITORY_URL}, please remove it manually so this job can complete successfully; exiting with code 1"
        exit 1
    fi

    # Piggy-back: The previous step command may have added the Git-ChgLog configuration. Lets commit
    # here to reduce duplicating the commit code there.
    gitChgLogConfigDir=$(dirname "${PARAM_CONFIG_FILE}")
    git add CHANGELOG.md "${gitChgLogConfigDir}"
    git status
    git config --global user.name "${CIRCLE_USERNAME}"
    git config --global user.email "${CIRCLE_USERNAME}@users.noreply.${PARAM_GH_SERVER}"
    git checkout -b "${GEN_BRANCH_NAME}"
    mergeBranchCommitMsg="Updated the ${PARAM_CHANGELOG_FILE}"
    git commit -m "${mergeBranchCommitMsg}" -m "automated update of ${PARAM_CHANGELOG_FILE}"
    # Do not run when sourced for bats-core
    # TODO: This can be tested if you mock the gh, git, and setup a dummy repo at test time.
    if [ "${0#*$ORB_TEST_ENV}" == "$0" ]; then
        git push origin "${GEN_BRANCH_NAME}"
        # Switch to SSH to use the token stored in the environment variable GH_TOKEN.
        gh config set git_protocol ssh --host "${PARAM_GH_SERVER}"
        echo
        echo
        # see: https://josh-ops.com/posts/gh-auth-login-in-actions/
        # NOTE: Using just GH_TOKEN set in the environment seems to fail when you have
        #       to supply the --hostname flag to point to a GHE server.
        if [ "${PARAM_GH_SERVER}" != "github.com" ]; then
            echo "login to ${PARAM_GH_SERVER}"
            echo "${GH_TOKEN}" | gh auth login --hostname "${PARAM_GH_SERVER}" --with-token
            echo
            echo
        fi
        echo "auth status of ${PARAM_GH_SERVER}"
        gh auth status --hostname "${PARAM_GH_SERVER}"
        echo
        echo
        echo "Making a PR"
        gh pr create --base "${PARAM_BRANCH}" --head "${GEN_BRANCH_NAME}" --fill
        sleep 5
        gh pr merge --auto "--${PARAM_MERGE_TYPE}"

        waitForPrToMerge
        echo "trigger-tag-and-release" > trigger.txt
        echo
        echo
        ls -la .
    fi
}

waitForPrToMerge() {
    # Wait until the branch is fully merged. and the merge branch has been updated.
    # This will help make sure that operations started in this job complete before moving on.
    printf "%s" "merging pr is "
    # 1. Loop for so many seconds
    counter=0
    while [ $counter -lt 10 ]; do
        # 2. Fetch remote changes
        git fetch --all -p
        # 3. Get the latest commit of the merge branch
        currCommit=$(git rev-parse origin/"${PARAM_BRANCH}")
        # 4. Check to see if the merge branch previous commit and current commit have changed.
        if [ "${currCommit}" != "${prevCommit}" ]; then
            echo " done"
            currCommitMsg=$(git show-branch --no-name "${currCommit}")
            # 5. If the commit messages are the same, then make a file to persist to the next job
            if [ "${currCommitMsg}" = "${mergeBranchCommitMsg}" ]; then
                echo "merge has completed successfully"
                echo "${currCommit}" > "${PARAM_COMMIT_FILE}"
                cm=$(cat "${PARAM_COMMIT_FILE}")
                printf "cm = %s"$'\n' "${cm}"
            fi
            # Exit the loop
            break
        else
            printf "."
        fi
        counter=$((counter+1))
        # Wait a second
        sleep 1
    done
}

# Will not run if sourced for bats-core tests.
# View src/tests for more information.
ORB_TEST_ENV="bats-core"
if [ "${0#*$ORB_TEST_ENV}" == "$0" ]; then
    MergeChangelog
fi
