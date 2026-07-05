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

include proto.mk

# https://github.com/docker/compose/releases
DOCKERCOMPOSE_VERSION = 5.3.0
# https://developer.hashicorp.com/terraform/install
TERRAFORM_VERSION = 1.15.7
# https://github.com/cloudfra/certtool/releases
CERTTOOL_VERSION = 0.2.2
# https://github.com/hadolint/hadolint/releases
HADOLINT_VERSION = 2.14.0

ifeq ($(OS),Windows_NT)
	DOCKERCOMPOSE_PACKAGE = https://github.com/docker/compose/releases/download/v$(DOCKERCOMPOSE_VERSION)/docker-compose-windows-x86_64.exe
	TERRAFORM_PACKAGE = https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_windows_amd64.zip
	CERTTOOL_PACKAGE = https://github.com/cloudfra/certtool/releases/download/v$(CERTTOOL_VERSION)/certtool-amd64.exe
	HADOLINT_PACKAGE = https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-windows-x86_64.exe
else
	UNAME_S := $(shell uname -s)
	UNAME_ARCH := $(shell uname -m)
	ifeq ($(UNAME_S),Linux)
		ifeq ($(UNAME_ARCH),arm)
			DOCKERCOMPOSE_PACKAGE = https://github.com/docker/compose/releases/download/v$(DOCKERCOMPOSE_VERSION)/docker-compose-linux-aarch64
			TERRAFORM_PACKAGE = https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_linux_arm64.zip
			CERTTOOL_PACKAGE = https://github.com/cloudfra/certtool/releases/download/v$(CERTTOOL_VERSION)/certtool-arm
			HADOLINT_PACKAGE = https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-linux-arm64
		else
			DOCKERCOMPOSE_PACKAGE = https://github.com/docker/compose/releases/download/v$(DOCKERCOMPOSE_VERSION)/docker-compose-linux-x86_64
			TERRAFORM_PACKAGE = https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_linux_amd64.zip
			CERTTOOL_PACKAGE = https://github.com/cloudfra/certtool/releases/download/v$(CERTTOOL_VERSION)/certtool-amd64
			HADOLINT_PACKAGE = https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-linux-x86_64
		endif
	endif
	ifeq ($(UNAME_S),Darwin)
		DOCKERCOMPOSE_PACKAGE = https://github.com/docker/compose/releases/download/v$(DOCKERCOMPOSE_VERSION)/docker-compose-darwin-aarch64
		TERRAFORM_PACKAGE = https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_darwin_arm64.zip
		CERTTOOL_PACKAGE = https://github.com/cloudfra/certtool/releases/download/v$(CERTTOOL_VERSION)/certtool-arm64-darwin
		HADOLINT_PACKAGE = https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-macos-arm64
	endif
endif

GO_WITH_PROXY = go
GO = GOPROXY=off go
GO_RACE=-race
DOCKER = docker
TAR = tar

SHORT_SHA = $(shell git rev-parse --short=7 HEAD | tr -d [:punct:])
DIRTY_VERSION = v0.0.0-$(SHORT_SHA)
VERSION = $(shell git describe --tags || (echo $(DIRTY_VERSION) && exit 1))
BUILD_DATE = $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
TAG := $(VERSION)

export PATH := $(PWD)/build/toolchain/bin:$(PATH)
SOURCE_DIRS=$(shell go list ./... | grep -v '/vendor/')

REGISTRY = ghcr.io/cloudfra
PROTOS =
TEST_ASSETS =
ASSETS = $(PROTOS)
ALL_APPS = example

TERRAFORM = $(REPOSITORY_ROOT)/build/toolchain/bin/terraform$(EXE)
TOOLCHAIN = build/toolchain/bin/gocover-cobertura$(EXE) build/toolchain/bin/docker-compose$(EXE) build/toolchain/bin/terraform$(EXE) build/toolchain/bin/vizb$(EXE) build/toolchain/bin/certtool$(EXE) $(PROTOC_TOOLCHAIN)

GO_TEST_COUNT = 25

LINUX_PLATFORMS = linux/386 linux/amd64 linux/arm/v5 linux/arm/v6 linux/arm/v7 linux/arm64 linux/loong64 linux/s390x linux/ppc64 linux/ppc64le linux/riscv64 linux/mips64le linux/mips linux/mipsle linux/mips64
ANDROID_PLATFORMS = android/arm64 # android/386 android/amd64 android/arm android/arm/v5 android/arm/v6 android/arm/v7
WINDOWS_PLATFORMS = windows/386 windows/amd64 windows/arm64 # windows/arm/v5 windows/arm/v6 windows/arm/v7
MAIN_PLATFORMS = windows/amd64 linux/amd64 linux/arm64
IOS_PLATFORMS = # ios/amd64 ios/arm64
DARWIN_PLATFORMS = darwin/amd64 darwin/arm64
DRAGONFLY_PLATFORMS = dragonfly/amd64
FREEBSD_PLATFORMS = freebsd/386 freebsd/amd64 freebsd/arm/v5 freebsd/arm/v6 freebsd/arm/v7 freebsd/arm64
NETBSD_PLATFORMS = netbsd/amd64 netbsd/arm64 netbsd/386 netbsd/arm/v5 netbsd/arm/v6 netbsd/arm/v7
OPENBSD_PLATFORMS = openbsd/386 openbsd/amd64 openbsd/arm/v5 openbsd/arm/v6 openbsd/arm/v7 openbsd/arm64 # openbsd/mips64
PLAN9_PLATFORMS = plan9/386 plan9/amd64 plan9/arm/v5 plan9/arm/v6 plan9/arm/v7
SOLARIS_PLATFORMS = solaris/amd64
NICHE_PLATFORMS = js/wasm illumos/amd64 aix/ppc64 $(ANDROID_PLATFORMS) $(DARWIN_PLATFORMS) $(IOS_PLATFORMS) $(DRAGONFLY_PLATFORMS) $(FREEBSD_PLATFORMS) $(NETBSD_PLATFORMS) $(OPENBSD_PLATFORMS) $(PLAN9_PLATFORMS) $(SOLARIS_PLATFORMS)
ALL_PLATFORMS = $(LINUX_PLATFORMS) $(WINDOWS_PLATFORMS) $(NICHE_PLATFORMS)

MAIN_BINARIES = $(foreach app,$(ALL_APPS),$(foreach platform,$(MAIN_PLATFORMS),build/bin/$(platform)/$(app)$(if $(findstring windows,$(platform)),.exe,)))
WINDOWS_BINARIES = $(foreach app,$(ALL_APPS),$(foreach platform,$(WINDOWS_PLATFORMS),build/bin/$(platform)/$(app)$(if $(findstring windows,$(platform)),.exe,)))
ALL_BINARIES = $(foreach app,$(ALL_APPS),$(foreach platform,$(ALL_PLATFORMS),build/bin/$(platform)/$(app)$(if $(findstring windows,$(platform)),.exe,)))
CODESIGN_CERT ?= build/certs/codesign.crt
CODESIGN_KEY ?= build/certs/codesign.key
# A literal "," inside a $(if ...) argument is parsed as another argument
# separator, not part of the text - COMMA hides it behind a nested
# variable reference so it survives into objcopy's --set-section-flags.
COMMA := ,
RELEASE_BINARIES = $(foreach app,$(ALL_APPS),$(foreach platform,$(ALL_PLATFORMS),build/release/$(app)-$(subst /,_,$(platform))$(if $(findstring windows,$(platform)),.exe,)))

WINDOWS_VERSIONS = 1709 1803 1809 1903 1909 2004 20H2 ltsc2022 ltsc2025
BUILDX_BUILDER = buildx-builder
# --provenance/--sbom=false: buildx defaults to emitting an image index (manifest
# list) wrapping a single-platform build to carry attestations. `docker manifest
# create`/`annotate` can't reference into a nested index, which breaks the
# per-platform tags merged by the `images` target below.
DOCKER_EXTRA_FLAGS = --builder $(BUILDX_BUILDER) --provenance=false --sbom=false
# Both Dockerfiles declare BUILD_DATE/VCS_REF/BUILD_VERSION build-args for
# their OCI/label-schema LABELs; without these, every image ships with empty
# version/created/vcs-ref labels.
DOCKER_LABEL_ARGS = --build-arg BUILD_DATE=$(BUILD_DATE) --build-arg VCS_REF=$(SHORT_SHA) --build-arg BUILD_VERSION=$(VERSION)

all: $(ALL_BINARIES)
tools: $(TOOLCHAIN)
assets: $(ASSETS)
protos: $(PROTOS)
windows-binaries: $(WINDOWS_BINARIES)

build/packages/%-binaries.zip: $(ALL_BINARIES)
	mkdir -p $(dir $@)
	(cd build/bin/$*/; zip -qr9 $(REPOSITORY_ROOT)/$@ *)
	touch $(REPOSITORY_ROOT)/$@

release-binaries: $(RELEASE_BINARIES)

build/packages/release.tar.gz: $(ALL_BINARIES)
	mkdir -p $(dir $@)
	cd build/bin/; $(TAR) -cvf - * | gzip -9 - > $(REPOSITORY_ROOT)/$@
	touch $(REPOSITORY_ROOT)/$@

build/toolchain/bin/vizb$(EXE):
	# https://github.com/goptics/vizb
	GOBIN=$(TOOLCHAIN_BIN) $(GO_WITH_PROXY) install github.com/goptics/vizb@latest

build/archives/terraform.zip:
	mkdir -p $(ARCHIVES_DIR)/
	$(CURL) -o $(ARCHIVES_DIR)/terraform.zip -L $(TERRAFORM_PACKAGE)
	touch $@

build/toolchain/bin/terraform$(EXE): build/archives/terraform.zip
	mkdir -p $(TOOLCHAIN_BIN)
	mkdir -p $(TOOLCHAIN_DIR)/terraform-temp/
	cp $(ARCHIVES_DIR)/terraform.zip $(TOOLCHAIN_DIR)/terraform-temp/
	(cd $(TOOLCHAIN_DIR)/terraform-temp/ && unzip -q -j terraform.zip)
	cp $(TOOLCHAIN_DIR)/terraform-temp/terraform$(EXE) $(TOOLCHAIN_BIN)/terraform$(EXE)
	rm -rf $(TOOLCHAIN_DIR)/terraform-temp/

build/toolchain/bin/docker-compose$(EXE):
	mkdir -p $(TOOLCHAIN_BIN)
	curl -Lo $@ $(DOCKERCOMPOSE_PACKAGE)
	chmod +x $@

build/toolchain/bin/certtool$(EXE):
	mkdir -p $(TOOLCHAIN_BIN)
	$(CURL) -Lo $@ $(CERTTOOL_PACKAGE)
	chmod +x $@

ifeq ($(CODESIGN_CERT)|$(CODESIGN_KEY),build/certs/codesign.crt|build/certs/codesign.key)
build/certs/codesign.crt build/certs/codesign.key &: build/toolchain/bin/certtool$(EXE)
	mkdir -p $(dir $(CODESIGN_CERT))
	$(TOOLCHAIN_BIN)/certtool$(EXE) --code-sign --target=linux --public-certificate=$(CODESIGN_CERT) --private-key=$(CODESIGN_KEY)
endif

build/toolchain/bin/gocover-cobertura$(EXE):
	mkdir -p $(dir $@)
	GOBIN=$(dir $(REPOSITORY_ROOT)/$@) $(GO_WITH_PROXY) install github.com/t-yuki/gocover-cobertura@latest

# golangci-lint's own default config (errcheck, govet, ineffassign,
# staticcheck, unused) already covers what a standalone staticcheck run
# would, so it's the only Go correctness linter wired into `lint`.
build/toolchain/bin/golangci-lint$(EXE):
	mkdir -p $(dir $@)
	GOBIN=$(dir $(REPOSITORY_ROOT)/$@) $(GO_WITH_PROXY) install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest

# Stricter formatting than `go fmt` (gofmt superset).
build/toolchain/bin/gofumpt$(EXE):
	mkdir -p $(dir $@)
	GOBIN=$(dir $(REPOSITORY_ROOT)/$@) $(GO_WITH_PROXY) install mvdan.cc/gofumpt@latest

# Style/doc-comment linter; not covered by golangci-lint's default config.
build/toolchain/bin/revive$(EXE):
	mkdir -p $(dir $@)
	GOBIN=$(dir $(REPOSITORY_ROOT)/$@) $(GO_WITH_PROXY) install github.com/mgechev/revive@latest

build/toolchain/bin/tflint$(EXE):
	mkdir -p $(dir $@)
	GOBIN=$(dir $(REPOSITORY_ROOT)/$@) $(GO_WITH_PROXY) install github.com/terraform-linters/tflint@latest

build/toolchain/bin/actionlint$(EXE):
	mkdir -p $(dir $@)
	GOBIN=$(dir $(REPOSITORY_ROOT)/$@) $(GO_WITH_PROXY) install github.com/rhysd/actionlint/cmd/actionlint@latest

# Not a Go module, so it's fetched as a prebuilt binary like terraform/docker-compose above.
build/toolchain/bin/hadolint$(EXE):
	mkdir -p $(TOOLCHAIN_BIN)
	$(CURL) -o $@ -L $(HADOLINT_PACKAGE)
	chmod +x $@

build/bin/%: $(ASSETS)
	GOOS=$(word 3, $(subst /, ,$(dir $@))) GOARCH=$(word 4, $(subst /, ,$(dir $@))) GOARM=$(subst v,,$(word 5, $(subst /, ,$(dir $@)))) CGO_ENABLED=0 $(GO) build -ldflags="-X 'github.com/cloudfra/template-go/internal.version=$(VERSION)' -X 'github.com/cloudfra/template-go/internal.buildstamp=$(BUILD_DATE)'" -o $@ cmd/$(basename $(notdir $@))/$(basename $(notdir $@)).go
	touch $@

run: cmd/example/example.go
	$(GO) run cmd/example/example.go

lint: build/toolchain/bin/terraform$(EXE) build/toolchain/bin/golangci-lint$(EXE) build/toolchain/bin/gofumpt$(EXE) build/toolchain/bin/revive$(EXE) build/toolchain/bin/tflint$(EXE) build/toolchain/bin/actionlint$(EXE) build/toolchain/bin/hadolint$(EXE)
	$(GO) fmt ./...
	$(GO) vet ./...
	build/toolchain/bin/gofumpt$(EXE) -l -w .
	build/toolchain/bin/golangci-lint$(EXE) run ./...
	build/toolchain/bin/revive$(EXE) -set_exit_status ./...
	$(FIND) cmd -iname 'Dockerfile*' -exec build/toolchain/bin/hadolint$(EXE) {} +
	build/toolchain/bin/actionlint$(EXE)
	(cd install/terraform; $(TERRAFORM) fmt .)
	build/toolchain/bin/tflint$(EXE) --init --chdir install/terraform
	build/toolchain/bin/tflint$(EXE) --chdir install/terraform

bench: $(TEST_ASSETS)
	$(GO) test -bench=. -benchmem -tags testing ${SOURCE_DIRS}

benchmark.html: $(TEST_ASSETS) build/toolchain/bin/vizb$(EXE)
	$(GO) test -json -bench=. -benchmem -tags testing ${SOURCE_DIRS} | build/toolchain/bin/vizb$(EXE) -o benchmark.html

test: $(TEST_ASSETS)
	$(GO) test -tags testing ${SOURCE_DIRS}

tf-test: build/toolchain/bin/terraform$(EXE) $(TEST_ASSETS)
	# -backend=false: main.tftest.hcl mocks the providers and never touches
	# real state, so there's no need to configure the (real, per-environment)
	# GCS backend just to run tests.
	(cd install/terraform/; $(TERRAFORM) init -backend=false)
	(cd install/terraform/; $(TERRAFORM) test)

test-deflake: $(TEST_ASSETS)
	CGO_ENABLED=1 $(GO) test -tags testing $(GO_RACE) ${SOURCE_DIRS} -cover -count $(GO_TEST_COUNT) -test.short

coverage.txt: $(ASSETS)
	for sfile in ${SOURCE_DIRS} ; do \
		go test -race "$$sfile" -coverprofile=package.coverage -covermode=atomic; \
		if [ -f package.coverage ]; then \
			cat package.coverage >> coverage.txt; \
			$(RM) package.coverage; \
		fi; \
	done; \
	sed -i '2,$${/mode: /d;}' $@

coverage.xml: coverage.txt build/toolchain/bin/gocover-cobertura$(EXE)
	$(REPOSITORY_ROOT)/build/toolchain/bin/gocover-cobertura$(EXE) < $< > $@

upgrade-deps:
	$(GO_WITH_PROXY) get -u ./...
	$(GO_WITH_PROXY) mod tidy

deps:
	$(GO_WITH_PROXY) mod download

clean:
	rm -f coverage.txt
	-chmod -R +w build/
	rm -rf build/
	rm -rf output/

presubmit: tools lint all test-deflake

system-info:
	@echo "Number of Processors"
	@echo "$(shell nproc)"
	@echo ""
	@echo "Kernel Version"
	@uname -a
	@echo ""
	@echo "Storage Metrics"
	@df -h

ensure-builder:
	-$(DOCKER) buildx create --name $(BUILDX_BUILDER)

ALL_DOCKER_IMAGES = $(foreach app,$(ALL_APPS),docker-image-$(app))
docker-images: $(ALL_DOCKER_IMAGES)
docker-image-%: build/bin/linux/amd64/% ensure-builder
	$(DOCKER) buildx build $(DOCKER_EXTRA_FLAGS) --platform linux/amd64 --build-arg BINARY_PATH=$< $(DOCKER_LABEL_ARGS) --build-arg BINARY_NAME=$* -f cmd/$*/Dockerfile -t $(REGISTRY)/$*:$(TAG) . $(DOCKER_PUSH)


ALL_IMAGES = $(foreach app,$(ALL_APPS),$(REGISTRY)/$(app))
# https://github.com/docker-library/official-images#architectures-other-than-amd64
images: linux-images windows-images
	for image in $(ALL_IMAGES) ; do \
		$(DOCKER) manifest rm $$image:$(TAG) 2>/dev/null || true ; \
		$(DOCKER) manifest create $$image:$(TAG) $(foreach winver,$(WINDOWS_VERSIONS),$${image}:$(TAG)-windows_amd64-$(winver)) $(foreach platform,$(LINUX_PLATFORMS),$${image}:$(TAG)-$(subst /,_,$(platform))) ; \
		for winver in $(WINDOWS_VERSIONS) ; do \
			windows_version=`$(DOCKER) manifest inspect mcr.microsoft.com/windows/nanoserver:$${winver} | jq -r '.manifests[0].platform["os.version"]'`; \
			$(DOCKER) manifest annotate --os-version $${windows_version} $${image}:$(TAG) $${image}:$(TAG)-windows_amd64-$${winver} ; \
		done ; \
		$(DOCKER) manifest push $$image:$(TAG) ; \
	done

.SECONDEXPANSION:

ALL_LINUX_IMAGES = $(foreach app,$(ALL_APPS),$(foreach platform,$(LINUX_PLATFORMS),linux-image-$(app)-$(subst /,_,$(platform))))
linux-images: $(ALL_LINUX_IMAGES)

# Stems here are "<app>-<platform>" with platform underscore-joined (e.g.
# "example-linux_arm_v7"): GNU Make strips everything before the last "/"
# when matching a slash-free pattern, so a literal "/" in the platform
# portion would never match this rule. $(call platform,...)/$(call appname,...)
# (defined near the bottom of this file) split the stem back apart.
linux-image-%: build/bin/$$(subst _,/,$$(call platform,$$*))/$$(call appname,$$*) ensure-builder
	$(DOCKER) buildx build $(DOCKER_EXTRA_FLAGS) --platform $(subst _,/,$(call platform,$*)) --build-arg BINARY_PATH=$< $(DOCKER_LABEL_ARGS) --build-arg BINARY_NAME=$(call appname,$*) -f cmd/$(call appname,$*)/Dockerfile -t $(REGISTRY)/$(call appname,$*):$(TAG)-$(call platform,$*) . $(DOCKER_PUSH)

ALL_WINDOWS_IMAGES = $(foreach app,$(ALL_APPS),$(foreach winver,$(WINDOWS_VERSIONS),windows-image-$(app)-$(winver)))
windows-images: $(ALL_WINDOWS_IMAGES)

# Stems here are "<app>-<winver>" (e.g. "example-ltsc2022"); reuse the same
# platform/appname split even though the trailing token is a Windows version,
# not an OS/arch pair.
windows-image-%: build/bin/windows/amd64/$$(call appname,$$*).exe ensure-builder
	$(DOCKER) buildx build $(DOCKER_EXTRA_FLAGS) --platform windows/amd64 --build-arg BINARY_PATH=$< $(DOCKER_LABEL_ARGS) --build-arg BINARY_NAME=$(call appname,$*) -f cmd/$(call appname,$*)/Dockerfile.windows --build-arg WINDOWS_VERSION=$(call platform,$*) -t $(REGISTRY)/$(call appname,$*):$(TAG)-windows_amd64-$(call platform,$*) . $(DOCKER_PUSH)

.PHONY: all tools assets protos windows-binaries run lint bench test tf-test test-deflake ensure-builder docker-images images linux-images windows-images upgrade-deps deps clean presubmit system-info release-binaries no-sudo
.SECONDEXPANSION:

# "appname-linux_arm_v5" -> "linux_arm_v5"
platform = $(lastword $(subst -, ,$(basename $(1))))
# strip "-<platform>" to recover app name (hyphen-safe)
appname  = $(patsubst %-$(call platform,$(1)),%,$(basename $(1)))
# source path: build/bin/linux/arm/v5/appname (no extension on sources)
rel2bin  = build/bin/$(subst _,/,$(call platform,$(1)))/$(call appname,$(1))$(if $(findstring windows,$(platform)),.exe,)

build/release/%: $$(call rel2bin,$$*) $(CODESIGN_CERT) $(CODESIGN_KEY)
	@mkdir -p $(@D)
	cp $< $@
	touch $@
	$(if $(findstring windows,$(call platform,$*)),osslsigncode sign -certs $(CODESIGN_CERT) -key $(CODESIGN_KEY) -in $@ -out $@.signed && mv $@.signed $@ && chmod +x $@,)
	$(if $(findstring linux,$(call platform,$*)),openssl cms -sign -binary -in $@ -signer $(CODESIGN_CERT) -inkey $(CODESIGN_KEY) -outform DER -out $@.sig && objcopy --add-section .cloudfra_signature=$@.sig --set-section-flags .cloudfra_signature=noload$(COMMA)readonly $@ && rm -f $@.sig,)
