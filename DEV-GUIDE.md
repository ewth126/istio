# Developing for Istio

This document helps you get started to develop code for Istio.
If you're following this guide and find some problem, please [submit an issue](https://github.com/istio/istio/issues/new).
so we can improve the doc.

- [Prerequisites](#prerequisites)
  - [Setting up Go](#setting-up-go)
  - [Setting up Docker](#setting-up-docker)
  - [Setting up environment variables](#setting-up-environment-variables)
  - [Setting up personal access token](#setting-up-a-personal-access-token)
  - [Setting up a container registry](#setting-up-a-container-registry)
- [Git workflow](#git-workflow)
  - [Fork the main repository](#fork-the-main-repository)
  - [Clone your fork](#clone-your-fork)
  - [Enable pre commit hook](#enable-pre-commit-hook)
  - [Create a branch and make changes](#create-a-branch-and-make-changes)
  - [Keeping your fork in sync](#keeping-your-fork-in-sync)
  - [Committing changes to your fork](#committing-changes-to-your-fork)
  - [Creating a pull request](#creating-a-pull-request)
  - [Getting a code review](#getting-a-code-review)
  - [When to retain commits and when to squash](#when-to-retain-commits-and-when-to-squash)
- [Using the code base](#using-the-code-base)
  - [Building the code](#building-the-code)
  - [Building and pushing the containers](#building-and-pushing-the-containers)
  - [Building the Istio manifests](#building-the-istio-manifests)
  - [Cleaning outputs](#cleaning-outputs)
  - [Running tests](#running-tests)
  - [Getting coverage numbers](#getting-coverage-numbers)
  - [Auto-formatting source code](#auto-formatting-source-code)
  - [Running the linters](#running-the-linters)
  - [Running race detection tests](#running-race-detection-tests)
  - [Adding dependencies](#adding-dependencies)
  - [About testing](#about-testing)
- [Local development scripts](#collection-of-scripts-and-notes-for-developing-istio)

This document is intended to be relative to the branch in which it is found.
It is guaranteed that requirements will change over time for the development
branch, but release branches should not change.

## Prerequisites

Istio components only have few external dependencies you
need to setup before being able to build and run the code.

### Setting up Go

Many Istio components are written in the [Go](http://golang.org) programming language.
To build, you'll need a Go development environment. If you haven't set up a Go development
environment, please follow [these instructions](https://golang.org/doc/install)
to install the Go tools.

Istio currently builds with Go 1.9

### Setting up Docker

To run some of Istio's examples and tests, you need to set up Docker server.
Please follow [these instructions](https://docs.docker.com/engine/installation/)
for how to do this for your platform.

Ensure your UID is in the docker group to access the docker daemon as a non-root user:

```shell
sudo adduser $USER docker
```

where:
    username is your login name

### Setting up environment variables

Set up your GOPATH, add a path entry for Go binaries to your PATH, set the ISTIO
path, and set your GITHUB_USER used later in this document. These exports are
typically added to your ~/.profile:

```shell
export GOPATH=~/go
export PATH=$PATH:$GOPATH/bin
export ISTIO=$GOPATH/src/istio.io # eg. ~/go/src/istio.io

# Please change HUB to the desired HUB for custom docker container
# builds.
export HUB="docker.io/$USER"

# The Istio Docker build system will build images with a tag composed of
# $USER and timestamp. The codebase doesn't consistently use the same timestamp
# tag. To simplify development the development process when later using
# updateVersion.sh you may find it helpful to set TAG to something consistent
# such as $USER.
export TAG=$USER

# If your github username is not the same as your local user name (saved in the
# shell variable $USER), then replace "$USER" below with your github username
export GITHUB_USER=$USER
```

Execute a one time operation to contain the Istio source trees.

```shell
mkdir -p $ISTIO
```

### Setting up a personal access token

This is only necessary for core contributors in order to push changes to the main repos.
You can make pull requests without two-factor authentication
but the additional security is recommended for everyone.

To be part of the Istio organization, we require two-factor authentication, and
you must setup a personal access token to enable push via HTTPS. Please follow
[these instructions](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/)
for how to create a token.
Alternatively you can [add your SSH keys](https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/).

### Setting up a container registry

Follow the
[Google Container Registry Quickstart](https://cloud.google.com/container-registry/docs/quickstart).

## Git workflow

Below, we outline one of the more common Git workflows that core developers use.
Other Git workflows are also valid.

### Fork the main repository

1. Go to https://github.com/istio/istio
2. Click the "Fork" button (at the top right)

### Clone your fork

The commands below require that you have $GOPATH set ([$GOPATH
docs](https://golang.org/doc/code.html#GOPATH)). We highly recommend you put
Istio's code into your GOPATH. Note: the commands below will not work if
there is more than one directory in your `$GOPATH`.

```shell
cd $ISTIO
git clone https://github.com/$GITHUB_USER/istio.git
cd istio
git remote add upstream 'https://github.com/istio/istio.git'
git config --global --add http.followRedirects 1
```

### Enable pre-commit hook

NOTE: The precommit hook is not functional as of 11/08/2017 following the repo
reorganization. It should come back alive shortly.

Istio uses a local pre-commit hook to ensure that the code
passes local tests before being committed.

Run
```shell
user@host:~/GOHOME/src/istio.io/istio$ ./bin/pre-commit
Installing pre-commit hook
```
This hook is invoked every time you commit changes locally.
The commit is allowed to proceed only if the hook succeeds.

### Create a branch and make changes

```shell
git checkout -b my-feature
# Make your code changes
```

### Keeping your fork in sync

```shell
git fetch upstream
git rebase upstream/master
```

Note: If you have write access to the main repositories
(e.g. github.com/istio/istio), you should modify your Git configuration so
that you can't accidentally push to upstream:

```shell
git remote set-url --push upstream no_push
```

### Committing changes to your fork

When you're happy with some changes, you can commit them to your repo:

```shell
git add .
git commit
```
Then push the change to the fork. When prompted for authentication, use your
GitHub username as usual but the personal access token as your password if you
have not setup ssh keys. Please
follow [these instructions](https://help.github.com/articles/caching-your-github-password-in-git/#platform-linux)
if you want to cache the token.

```shell
git push origin my-feature
```

### Creating a pull request

1. Visit https://github.com/$GITHUB_USER/istio
2. Click the "Compare & pull request" button next to your "my-feature" branch.

### Getting a code review

Once your pull request has been opened it will be assigned to one or more
reviewers. Those reviewers will do a thorough code review, looking for
correctness, bugs, opportunities for improvement, documentation and comments,
and style.

Very small PRs are easy to review. Very large PRs are very difficult to
review. GitHub has a built-in code review tool, which is what most people use.

### When to retain commits and when to squash

Upon merge, all Git commits should represent meaningful milestones or units of
work. Use commits to add clarity to the development and review process.

Before merging a PR, squash any "fix review feedback", "typo", and "rebased"
sorts of commits. It is not imperative that every commit in a PR compile and
pass tests independently, but it is worth striving for. For mass automated
fixups (e.g. automated doc formatting), use one or more commits for the
changes to tooling and a final commit to apply the fixup en masse. This makes
reviews much easier.

Please do not use force push after submitting a PR to resolve review
feedback. Doing so results in an inability to see what has changed between
revisions of the PR. Instead submit additional commits until the PR is
suitable for merging. Once the PR is suitable for merging, the commits will
be squashed to simplify the commit.

## Using the code base

### Building the code

To build the core repo:

```shell
cd $ISTIO/istio
make build
```

This build command figures out what it needs to do and does not need any input from you.

### Building and pushing the containers

Build the containers in your local docker cache:

```shell
make docker
```

Push the containers to your registry:

```shell
make push
```

### Building the Istio manifests

Use [updateVersion.sh](https://github.com/istio/istio/blob/master/install/updateVersion.sh)
to generate new manifests with mixer, pilot, and ca_cert custom built containers:

```
cd $ISTIO/istio
install/updateVersion.sh -a${HUB},${TAG}
```

### Cleaning outputs

You can delete any build artifacts with:

```shell
make clean
```
### Running tests

You can run all the available tests with:

```shell
make test
```
### Getting coverage numbers

You can get the current unit test coverage numbers on your local repo by going to the top of the repo and entering:

```shell
make coverage
```

### Auto-formatting source code

You can automatically format the source code to follow our conventions by going to the
top of the repo and entering:

```shell
make fmt
```

### Running the linters

You can run all the linters we require on your local repo by going to the top of the repo and entering:

```shell
make lint
# To run only on your local changes
bin/linters.sh -s HEAD^
```

### Source file dependencies

You can keep track of dependencies between sources using:

```shell
make gazelle
```

### Race detection tests

You can run the test suite using the Go race detection tools using:

```shell
make racetest
```

### Adding dependencies

It will occasionally be necessary to add a new external dependency to the
system. Istio uses Go's [Dep](github.com/golang/dep) tool. To add a new
dependency, run the `dep ensure` command to update the Gopkg.lock files.

### About testing

Before sending pull requests you should at least make sure your changes have
passed both unit and integration tests. We only merge pull requests when
**all** tests are passing.

* Unit tests should be fully hermetic
  - Only access resources in the test binary.
* All packages and any significant files require unit tests.
* Unit tests are written using the standard Go testing package.
* The preferred method of testing multiple scenarios or input is
  [table driven testing](https://github.com/golang/go/wiki/TableDrivenTests)
* Concurrent unit test runs must pass.
