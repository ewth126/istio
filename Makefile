## Copyright 2017 Istio Authors
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

#-----------------------------------------------------------------------------
# Global Variables
#-----------------------------------------------------------------------------
TOP := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL := /bin/bash

# Make sure GOPATH is set based on the executing Makefile and workspace. Will override
# GOPATH from the env.
export GOPATH= $(shell cd ../../..; pwd)

# OUT is the directory where dist artifacts and temp files will be created.
OUT=${GOPATH}/out

GO ?= go

# Compile for linux/amd64 by default.
export GOOS ?= linux
export GOARCH ?= amd64

# @todo allow user to run for a single $PKG only?
PACKAGES := $(shell $(GO) list ./...)
GO_EXCLUDE := /vendor/|.pb.go|.gen.go
GO_FILES := $(shell find . -name '*.go' | grep -v -E '$(GO_EXCLUDE)')

BAZEL_STARTUP_ARGS ?=
BAZEL_BUILD_ARGS ?=
BAZEL_TEST_ARGS ?=

# Environment for tests, the directory containing istio and deps binaries.
# Typically same as GOPATH/bin, so tests work seemlessly with IDEs.
export ISTIO_BIN=${GOPATH}/bin

hub = ""
tag = ""

ifneq ($(strip $(HUB)),)
	hub =-hub ${HUB}
endif

ifneq ($(strip $(TAG)),)
	tag =-tag ${TAG}
endif

#-----------------------------------------------------------------------------
# Output control
#-----------------------------------------------------------------------------
VERBOSE ?= 0
V ?= $(or $(VERBOSE),0)
Q = $(if $(filter 1,$V),,@)
H = $(shell printf "\033[34;1m=>\033[0m")

.DEFAULT_GOAL := build

checkvars:
	@if test -z "$(TAG)"; then echo "TAG missing"; exit 1; fi
	@if test -z "$(HUB)"; then echo "HUB missing"; exit 1; fi

verify.preconditions:
	@if [ -d "vendor" ]; then echo "You have directory 'vendor' in the top-level directory, please remove it."\
	" Otherwise it will confuse Bazel." ; exit 1; fi

.PHONY: verify.preconditions

setup: pilot/platform/kube/config verify.preconditions


#-----------------------------------------------------------------------------
# Target: depend
#-----------------------------------------------------------------------------
.PHONY: depend 
.PHONY: depend.status depend.ensure depend.graph

depend: depend.ensure

Gopkg.lock: Gopkg.toml ; $(info $(H) generating) @
	$(Q) dep ensure -update

depend.status: Gopkg.lock ; $(info $(H) reporting dependencies status...)
	$(Q) dep status

# @todo only run if there are changes (e.g., create a checksum file?) 
# Update the vendor dir, pulling latest compatible dependencies from the
# defined branches.
depend.ensure: Gopkg.lock ; $(info $(H) ensuring dependencies are up to date...)
	$(Q) dep ensure

depend.graph: Gopkg.lock ; $(info $(H) visualizing dependency graph...)
	$(Q) dep status -dot | dot -T png | display

# Re-create the vendor directory, if it doesn't exist, using the checked in lock file
depend.vendor: vendor
	$(Q) dep ensure -vendor-only

vendor:
	dep ensure -update


#-----------------------------------------------------------------------------
# Target: precommit
#-----------------------------------------------------------------------------
.PHONY: precommit format check
.PHONY: fmt format.gofmt format.goimports format.bazel
.PHONY: check.vet check.lint

precommit: format check
format: format.goimports
fmt: format.gofmt format.goimports format.bazel # backward compatible with ./bin/fmt.sh
check: check.vet check.lint

format.gofmt: ; $(info $(H) formatting files with go fmt...)
	$(Q) gofmt -s -w $(GO_FILES)

format.goimports: ; $(info $(H) formatting files with goimports...)
	$(Q) goimports -w -local istio.io $(GO_FILES)

format.bazel: ; $(info $(H) formatting bazel files...)
	$(eval BAZEL_FILES = $(shell git ls-files | grep -e 'BUILD' -e 'WORKSPACE' -e 'BUILD.bazel' -e '.*\.bazel' -e '.*\.bzl'))
	$(Q) buildifier -mode=fix $(BAZEL_FILES)

# @todo fail on vet errors? Currently uses `true` to avoid aborting on failure
check.vet: ; $(info $(H) running go vet on packages...)
	$(Q) $(GO) vet $(PACKAGES) || true

# @todo fail on lint errors? Currently uses `true` to avoid aborting on failure
# @todo remove _test and mock_ from ignore list and fix the errors?
check.lint: ; $(info $(H) running golint on packages...)
	$(eval LINT_EXCLUDE := $(GO_EXCLUDE)|_test.go|mock_)
	$(Q) for p in $(PACKAGES); do \
		golint $$p | grep -v -E '$(LINT_EXCLUDE)' ; \
	done || true;

# @todo gometalinter targets?

build: setup
	bazel $(BAZEL_STARTUP_ARGS) build $(BAZEL_BUILD_ARGS) //...

#-----------------------------------------------------------------------------
# Target: go build
#-----------------------------------------------------------------------------

.PHONY: go-build

.PHONY: pilot
pilot: vendor
	go install istio.io/istio/pilot/cmd/pilot-discovery

.PHONY: pilot-agent
pilot-agent: vendor
	go install istio.io/istio/pilot/cmd/pilot-agent

.PHONY: istioctl
istioctl: vendor
	go install istio.io/istio/pilot/cmd/istioctl

.PHONY: sidecar-initializer
sidecar-initializer: vendor
	go install istio.io/istio/pilot/cmd/sidecar-initializer

.PHONY: mixs
mixs: vendor
	go install istio.io/istio/mixer/cmd/mixs

.PHONY: mixc
mixc: vendor
	go install istio.io/istio/mixer/cmd/mixs

go-build: pilot istioctl pilot-agent sidecar-initializer mixs mixc

#-----------------------------------------------------------------------------
# Target: go test
#-----------------------------------------------------------------------------

.PHONY: go-test localTestEnv

GOTEST_PARALLEL ?= '-test.parallel=4'

localTestEnv:
	bin/testEnvLocalK8S.sh ensure
	go install istio.io/istio/pilot/test/server
	go install istio.io/istio/pilot/test/client
	go install istio.io/istio/pilot/test/eurekamirror

.PHONY: pilot-test
pilot-test: pilot-agent localTestEnv
	go test ${T} ${GOTEST_PARALLEL} ./pilot/...

.PHONY: mixer-test
mixer-test: mixs
	# Some tests use relative path "testdata", must be run from mixer dir
	(cd mixer; go test ${T} ${GOTEST_PARALLEL} ./...)

.PHONY: broker-test
broker-test: vendor
	go test ${T} ./broker/...

.PHONY: security-test
security-test:
	go test ${T} ./security/...

# Run coverage tests
go-test: pilot-test mixer-test security-test broker-test

#-----------------------------------------------------------------------------
# Target: Code coverage ( go )
#-----------------------------------------------------------------------------

.PHONY: pilot-cov
pilot-cov:
	bin/parallel-codecov.sh pilot

.PHONY: mixer-cov
mixer-cov:
	bin/parallel-codecov.sh mixer

.PHONY: broker-cov
broker-cov:
	bin/parallel-codecov.sh broker

.PHONY: security-cov
security-cov:
	bin/parallel-codecov.sh security

# Run coverage tests
cov: pilot-cov mixer-cov security-cov broker-cov


#-----------------------------------------------------------------------------
# Target: precommit
#-----------------------------------------------------------------------------
.PHONY: clean
.PHONY: clean.bazel clean.go

clean: clean.bazel

clean.bazel: ; $(info $(H) cleaning...)
	$(Q) bazel clean

clean.go: ; $(info $(H) cleaning...)
	$(eval GO_CLEAN_FLAGS := -i -r)
	$(Q) $(GO) clean $(GO_CLEAN_FLAGS)

test: setup
	bazel $(BAZEL_STARTUP_ARGS) test $(BAZEL_TEST_ARGS) //...

docker:
	$(TOP)/security/bin/push-docker ${hub} ${tag} -build-only
	$(TOP)/pilot/bin/push-docker ${hub} ${tag} -build-only
	$(TOP)/mixer/bin/push-docker ${hub} ${tag} -build-only

push: checkvars
	$(TOP)/bin/push $(HUB) $(TAG)

artifacts: docker
	@echo 'To be added'

pilot/platform/kube/config:
	touch $@

kubelink:
	ln -fs ~/.kube/config pilot/platform/kube/

.PHONY: artifacts build checkvars clean docker test setup push kubelink

#-----------------------------------------------------------------------------
# Target: environment and tools
#-----------------------------------------------------------------------------
.PHONY: show.env show.goenv

show.env: ; $(info $(H) environment variables...)
	$(Q) printenv

show.goenv: ; $(info $(H) go environment...)
	$(Q) $(GO) version
	$(Q) $(GO) env

# show makefile variables. Usage: make show.<variable-name>
show.%: ; $(info $* $(H) $($*))
	$(Q) true

#-----------------------------------------------------------------------------
# Target: artifacts and distribution
#-----------------------------------------------------------------------------

${OUT}/dist/Gopkg.lock:
	mkdir -p ${OUT}/dist
	cp Gopkg.lock ${OUT}/dist/

# Binary/built artifacts of the distribution
dist-bin: ${OUT}/dist/Gopkg.lock

dist: dist-bin
