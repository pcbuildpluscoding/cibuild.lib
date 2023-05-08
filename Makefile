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

GO ?= go
GOOS ?= $(shell go env GOOS)
ifeq ($(GOOS),windows)
	BIN_EXT := .exe
endif

PACKAGE := github.com/pcbuildpluscoding/mpproxy
BINDIR ?= /usr/local/bin

VERSION=$(shell git describe --match 'v[0-9]*' --dirty='.m' --always --tags)
VERSION_TRIMMED := $(VERSION:v%=%)
REVISION=$(shell git rev-parse HEAD)$(shell if ! git diff --no-ext-diff --quiet --exit-code; then echo .m; fi)

export GO_BUILD=GO111MODULE=on CGO_ENABLED=1 GOOS=$(GOOS) $(GO) build -ldflags "-s -w -X $(PACKAGE)/version.Version=$(VERSION) -X $(PACKAGE)/version.Revision=$(REVISION)"

ifdef VERBOSE
	VERBOSE_FLAG := -v
endif

all: binaries

help:
	@echo "Usage: make <target>"
	@echo
	@echo " * 'install' - Install binaries to system locations."
	@echo " * 'binaries' - Build mpproxy."
	@echo " * 'clean' - Clean artifacts."

mpproxy:
	$(GO_BUILD) $(VERBOSE_FLAG) -o $(CURDIR)/bin/mpproxy$(BIN_EXT) $(PACKAGE)

clean:
	find . -name \*~ -delete
	find . -name \#\* -delete
	rm -f bin/* 
	rm -f release/* 
	rm -rf vendor 

binaries: mpproxy

install:
	install -D -m 755 $(CURDIR)/bin/mpproxy $(DESTDIR)$(BINDIR)/mpproxy
	install -D -m 755 $(CURDIR)/extras/rootless/containerd-rootless.sh $(DESTDIR)$(BINDIR)/containerd-rootless.sh
	install -D -m 755 $(CURDIR)/extras/rootless/containerd-rootless-setuptool.sh $(DESTDIR)$(BINDIR)/containerd-rootless-setuptool.sh

define make_artifact_full_linux
	DOCKER_BUILDKIT=1 docker build --output type=tar,dest=$(CURDIR)/release/mpproxy-full-$(VERSION_TRIMMED)-linux-$(1).tar --target out-full --platform $(1) $(CURDIR)
	gzip -9 $(CURDIR)/release/mpproxy-full-$(VERSION_TRIMMED)-linux-$(1).tar
endef

TAR_OWNER0_FLAGS=--owner=0 --group=0
TAR_FLATTEN_FLAGS=--transform 's/.*\///g'

artifacts: clean
	GOOS=linux GOARCH=amd64       make -C $(CURDIR) binaries
	tar $(TAR_OWNER0_FLAGS) $(TAR_FLATTEN_FLAGS) -czvf $(CURDIR)/release/mpproxy-$(VERSION_TRIMMED)-linux-amd64.tar.gz  bin/mpproxy mpproxy.go go.mod go.sum

# rm -f $(CURDIR)/bin/mpproxy

# $(call make_artifact_full_linux,amd64)
# $(call make_artifact_full_linux,arm64)

# go mod vendor
# tar $(TAR_OWNER0_FLAGS) -czf $(CURDIR)/release/mpproxy-$(VERSION_TRIMMED)-go-mod-vendor.tar.gz go.mod go.sum vendor

.PHONY: \
	help \
	mpproxy \
	clean \
	binaries \
	install \
	artifacts
