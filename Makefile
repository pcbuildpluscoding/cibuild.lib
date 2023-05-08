#   Copyright The containerd Authors.

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# -----------------------------------------------------------------------------
# Portions from https://github.com/kubernetes-sigs/cri-tools/blob/v1.19.0/Makefile
# Copyright The Kubernetes Authors.
# Licensed under the Apache License, Version 2.0
# -----------------------------------------------------------------------------

ARCHIVE_PATH=$(shell cat git_archive_path.txt | xargs)
VERSION=$(shell git describe --match 'v[0-9]*' --dirty='.m' --always --tags)
VERSION_TRIMMED := $(VERSION:v%=%)
REVISION=$(shell git rev-parse HEAD)$(shell if ! git diff --no-ext-diff --quiet --exit-code; then echo .m; fi)

# export GO_BUILD=GO111MODULE=on CGO_ENABLED=1 GOOS=$(GOOS) $(GO) build -ldflags "-s -w -X $(PACKAGE)/version.Version=$(VERSION) -X $(PACKAGE)/version.Revision=$(REVISION)"

ifdef VERBOSE
	VERBOSE_FLAG := -v
endif

help:
	@echo "Usage: make <target>"
	@echo
	@echo " * 'install' - Install binaries to system locations."
	@echo " * 'binaries' - Build mpproxy."
	@echo " * 'clean' - Clean artifacts."

clean:
	rm -f release/* 

TAR_OWNER0_FLAGS=--owner=0 --group=0
TAR_FLATTEN_FLAGS=--transform 's/.*\///g'

artifacts: clean
	git archive --output $(CURDIR)/release/content-$(VERSION_TRIMMED).tar.gz HEAD $(ARCHIVE_PATH) 

.PHONY: \
	help \
	clean \
	artifacts
