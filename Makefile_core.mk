# Copyright 2026 Cloudfra
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

COMMA := ,
EXE =
FIND = find

REPOSITORY_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BUILD_DIR = $(REPOSITORY_ROOT)/build
ARCHIVES_DIR = $(BUILD_DIR)/archives
TOOLCHAIN_DIR = $(BUILD_DIR)/toolchain
THIRDPARTY_DIR = $(REPOSITORY_ROOT)/third_party

TOOLCHAIN_GO = go
CURL = curl --retry 5 --retry-connrefused

# Pinned toolchain releases are installed here, each into its own
# <tool>-<version>/ directory, and run from there. A version bump installs only
# that tool, and an installed tool is never rebuilt or re-extracted, so a build
# with a populated cache does no toolchain work at all. It defaults to
# build/toolchain, which `make clean` removes as before; CI points it at a
# directory outside the workspace (see .github/workflows/deploy.yaml) that
# survives `actions/checkout`'s `git clean -ffdx` and `make clean`, so each
# release is installed once per runner. `make clean-cache` empties it.
TOOLCHAIN_CACHE ?= $(TOOLCHAIN_DIR)
override TOOLCHAIN_CACHE := $(abspath $(TOOLCHAIN_CACHE))
# tool_path TOOL,VERSION names the installed binary of a pinned release.
tool_path = $(TOOLCHAIN_CACHE)/$(1)-$(2)/$(1)$(EXE)
# cache_path TOOL,VERSION,URL names a release download kept in the cache.
cache_path = $(TOOLCHAIN_CACHE)/$(1)-$(2)/$(notdir $(3))

# Jobs on one runner share TOOLCHAIN_CACHE, so every recipe below works in a
# per-process scratch name next to $@ and renames the finished file into place:
# a concurrent job never sees a partial file, and curl -f keeps an HTTP error
# page from being installed. If the rename fails because another job already
# installed $@ (Windows will not replace a running .exe), its copy is used.
#
# Download URL to $@.
DOWNLOAD = $(CURL) -fL -o "$@.$$$$.tmp" "$(1)" && mv -f "$@.$$$$.tmp" "$@"; \
	status=$$?; rm -f "$@.$$$$.tmp"; exit $$status
# Download the prebuilt binary at URL to $@.
DOWNLOAD_TOOL = mkdir -p "$(dir $@)" && $(CURL) -fL -o "$@.$$$$.tmp" "$(1)" && \
	chmod +x "$@.$$$$.tmp" && { mv -f "$@.$$$$.tmp" "$@" || [ -f "$@" ]; }; \
	status=$$?; rm -f "$@.$$$$.tmp"; exit $$status
# Unpack the release archive at local path ARCHIVE, or at URL when ARCHIVE is
# empty, and install the file in it named like $@ (wherever the archive keeps
# it) as $@. It is touched first, since the archive's own timestamp would leave
# $@ older than a local ARCHIVE and reinstalled on every run.
INSTALL_FROM_ARCHIVE = tmp="$@.$$$$.d" && rm -rf "$$tmp" && mkdir -p "$$tmp" && \
	archive="$(if $(1),$(1),$$tmp/$(notdir $(2)))" && \
	$(if $(1),true,$(CURL) -fL -o "$$archive" "$(2)") && \
	(cd "$$tmp" && case "$$archive" in *.zip) unzip -q "$$archive" ;; *) tar -xf "$$archive" ;; esac) && \
	bin="$$($(FIND) "$$tmp" -type f -name "$(notdir $@)" | head -n 1)" && [ -n "$$bin" ] && \
	chmod +x "$$bin" && touch "$$bin" && { mv -f "$$bin" "$@" || [ -f "$@" ]; }; \
	status=$$?; rm -rf "$$tmp"; exit $$status
# go install PACKAGE@VERSION as $@. Go's module and build caches stay in the
# default GOPATH/GOCACHE, outside the repo: a read-only module cache under
# build/ is what made the Windows runner's `git clean -ffdx` take over a
# minute.
GO_INSTALL_TOOL = tmp="$@.$$$$.d" && rm -rf "$$tmp" && mkdir -p "$$tmp" && \
	GOBIN="$$tmp" $(TOOLCHAIN_GO) install $(1) && \
	{ mv -f "$$tmp/$(notdir $@)" "$@" || [ -f "$@" ]; }; \
	status=$$?; rm -rf "$$tmp"; exit $$status

SHORT_SHA = $(shell git rev-parse --short=7 HEAD | tr -d [:punct:])
DIRTY_VERSION = v0.0.0-$(SHORT_SHA)
VERSION = $(shell git describe --tags || (echo $(DIRTY_VERSION) && exit 1))
BUILD_DATE = $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
TAG := $(VERSION)

SOURCE_DIRS=$(shell go list ./... | grep -v '/vendor/')

ifeq ($(OS),Windows_NT)
	HOST_OS = windows
	HOST_PLATFORM = windows_amd64
	HOST_ARCH = amd64
	# Give priority to /usr/bin because it conflicts with C:\Windows\system32 within Msys32 environment.
	FIND = /usr/bin/find.exe
	EXE = .exe
	SED_REPLACE = sed -i
else
	UNAME_S := $(shell uname -s)
	UNAME_ARCH := $(shell uname -m)
	ifeq ($(UNAME_S),Linux)
		HOST_OS = linux
		SED_REPLACE = sed -i
		ifneq ($(filter arm aarch64,$(UNAME_ARCH)),)
			HOST_PLATFORM = linux_arm
			HOST_ARCH = arm
		else
			HOST_PLATFORM = linux_amd64
			HOST_ARCH = amd64
		endif
	endif
	ifeq ($(UNAME_S),Darwin)
		HOST_OS = darwin
		SED_REPLACE = sed -i ''
		ifeq ($(UNAME_ARCH),arm64)
			HOST_PLATFORM = darwin_arm64
			HOST_ARCH = arm64
		else
			HOST_PLATFORM = darwin_amd64
			HOST_ARCH = amd64
		endif
	endif
endif
