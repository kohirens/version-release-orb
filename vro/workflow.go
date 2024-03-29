package main

import (
	"fmt"
	"github.com/kohirens/stdlib/log"
	"github.com/kohirens/version-release-orb/vro/pkg/circleci"
	"github.com/kohirens/version-release-orb/vro/pkg/gitchglog"
	"github.com/kohirens/version-release-orb/vro/pkg/gittoolbelt"
)

type Workflow struct {
	// GitHubClient GitHub API client
	GitHubClient circleci.GithubClient
	// Token A CircleCI API token
	Token string
}

func NewWorkflow(token string, ghClient circleci.GithubClient) *Workflow {
	return &Workflow{
		GitHubClient: ghClient,
		Token:        token,
	}
}
func (wf *Workflow) PublishChangelog(wd, chgLogFile, branch string) error {
	// Step 1: Determine if the changelog has updates
	isUpdated, err1 := IsChangelogUpToDate(wd, chgLogFile)
	if err1 != nil {
		return err1
	}

	if isUpdated {
		// If there were no changes to publish then how did we get here?
		// This pipeline should not have been triggered.
		return fmt.Errorf(stderr.NoChangelogChanges)
	}

	// Step 2: There are changes, so get the repositories semantic version info.
	si, err2 := gittoolbelt.Semver(wd)
	if err2 != nil {
		return fmt.Errorf(stderr.NoSemverInfo, err2)
	}

	// Step 3: Generate a new changelog using the version info.
	if e := gitchglog.RebuildChangelog(wd, chgLogFile, si); e != nil {
		return e
	}

	// Step 4: Commit, push, and publish the changelog.
	return wf.GitHubClient.PublishChangelog(wd, branch, chgLogFile)
}

func (wf *Workflow) PublishReleaseTag(chgLogFile, branch, wd string) error {
	// Step 1: Grab semantic version info.
	si, err1 := gittoolbelt.Semver(wd)
	if err1 != nil {
		return fmt.Errorf(stderr.CouldNotGetVersion, err1)
	}

	// Step 2: Publish a new tag on GitHub.
	rr, err2 := wf.GitHubClient.TagAndRelease(branch, si)
	if err2 != nil {
		return err2
	}

	log.Logf(stdout.ReleaseTag, rr.Name)

	return nil
}
