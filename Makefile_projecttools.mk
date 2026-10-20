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

include Makefile_core.mk

# Tools this project needs that the template's toolchain doesn't ship: a
# codec, an emulator, a code generator, a fuzzer -- anything a build, test or
# benchmark runs as an external command. Both lists are empty in the
# template, so a project that needs nothing gets exactly the build it has
# today.
#
# A project fills them in in its own Makefile, above the include of
# Makefile_build.mk that pulls this file in:
#
#   PROJECT_TOOLS     the tool files, as make targets. Put them under
#                     build/toolchain/bin like every other tool: that
#                     directory is already on PATH (see Makefile_core.mk), so
#                     a build or test finds the tool by name with no extra
#                     plumbing, and `make clean` removes it.
#   PROJECT_ARCHIVES  the downloads the tools are unpacked from, under
#                     build/archives.
#
# Setting them is all the wiring needed: `make tools` and `make assets` fetch
# the tools, `make test`/`make bench` wait for them, `make projecttools`
# builds just them, and `make clean` removes them. How they are produced is
# the project's business -- any recipe will do. gowebserver's ffmpeg, for
# instance, is fetched by a command in its own repo, which is what lets it
# pick the build for the platform, verify a checksum and accept a license:
#
#   PROJECT_TOOLS = build/toolchain/bin/ffmpeg$(EXE)
#
#   build/toolchain/bin/ffmpeg$(EXE):
#       $(GO) run ./internal/tools/installffmpeg -o "$@"
#
# A tool that is a plain release download needs two rules and the macros
# below:
#
#   # https://github.com/BtbN/FFmpeg-Builds/releases (GPL builds: a project
#   # has to accept ffmpeg's license before its CI downloads one)
#   FFMPEG_VERSION = 7.1
#   FFMPEG_PACKAGE = https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2025-04-27-18-06/ffmpeg-linux-x86_64-$(FFMPEG_VERSION).tar.xz
#   PROJECT_TOOLS = build/toolchain/bin/ffmpeg$(EXE)
#   PROJECT_ARCHIVES = build/archives/ffmpeg.tar.xz
#
#   build/archives/ffmpeg.tar.xz:
#       $(call download_archive,$(FFMPEG_PACKAGE),$@)
#
#   build/toolchain/bin/ffmpeg$(EXE): build/archives/ffmpeg.tar.xz
#       $(call install_tool,$<,$@,bin/ffmpeg,1)
#
# Keep the version in a variable named *_VERSION and the URL in *_PACKAGE:
# scripts/template-go/update-project.sh scans every Makefile_*.mk for those
# and moves them to the newest release, which is how the pins in
# Makefile_toolchain.mk are kept current.
#
# This file is template-managed: a template sync replaces it wholesale, so
# project settings belong in the Makefile. Everything here is assigned with
# ?= for the same reason -- the project's assignments come first, and a plain
# assignment in an included file would overwrite them.

PROJECT_TOOLS ?=
PROJECT_ARCHIVES ?=

# A test that shells out to one of this project's tools shouldn't have to say
# so: the test and benchmark rules wait for TEST_DEPS, which Makefile_build.mk
# initializes to the test assets and this file extends with the tools. Empty
# PROJECT_TOOLS leaves it exactly as it was.
TEST_DEPS += $(PROJECT_TOOLS)

# archive_stem ARCHIVE: the archive's name without its suffixes, used for the
# temporary directory an unpack lands in ("ffmpeg.tar.xz" -> "ffmpeg").
archive_stem = $(word 1,$(subst ., ,$(notdir $(1))))

# $(call download_archive,PACKAGE_URL,DEST)
#
# Fetches a release archive into build/archives. Keeping the download a
# separate target from the unpack means a failed unpack doesn't re-download,
# and `touch`ing it means the timestamp, not the size, says it is complete.
define download_archive
	mkdir -p "$(dir $(2))"
	$(CURL) -o "$(REPOSITORY_ROOT)/$(2)" -L "$(1)"
	touch "$(REPOSITORY_ROOT)/$(2)"
endef

# $(call install_binary,PACKAGE_URL,DEST)
#
# For a tool that ships as a single executable rather than an archive, like
# docker-compose and certtool in Makefile_toolchain.mk.
define install_binary
	mkdir -p "$(dir $(2))"
	$(CURL) -o "$(REPOSITORY_ROOT)/$(2)" -L "$(1)"
	chmod +x "$(REPOSITORY_ROOT)/$(2)"
endef

# $(call install_tool,ARCHIVE,DEST,MEMBER[,STRIP])
#
# Unpacks ARCHIVE into a temporary directory under build/toolchain, copies
# MEMBER out of it to DEST, marks it executable, and drops the temporary
# directory. STRIP is the number of leading path components to drop (tar's
# --strip-components); for a .zip it means "flatten every path" (unzip -j),
# so MEMBER is then the bare file name. The extractor is picked from the
# archive's suffix, which is what the equivalent rules in
# Makefile_toolchain.mk each do by hand.
#
# The whole thing is one shell command so the temporary directory name can be
# reused, which is why it starts with `set -e`: without it the trailing
# `rm -rf` decides the exit status, so a failed download, unpack or copy looks
# like a successful build. A failure does leave the temporary directory
# behind; the next run of the rule removes it before unpacking again, and
# `make clean` removes build/toolchain wholesale.
define install_tool
	set -e; \
	tmp="$(TOOLCHAIN_DIR)/$(call archive_stem,$(1))-temp"; \
	mkdir -p "$(dir $(2))"; \
	rm -rf "$$tmp"; \
	mkdir -p "$$tmp"; \
	case "$(1)" in \
		*.zip) (cd "$$tmp" && unzip -q -o $(if $(4),-j,) "$(REPOSITORY_ROOT)/$(1)");; \
		*.tar.gz|*.tgz) tar -xzf "$(REPOSITORY_ROOT)/$(1)" -C "$$tmp" $(if $(4),--strip-components=$(4),);; \
		*.tar.xz) tar -xJf "$(REPOSITORY_ROOT)/$(1)" -C "$$tmp" $(if $(4),--strip-components=$(4),);; \
		*.tar.bz2) tar -xjf "$(REPOSITORY_ROOT)/$(1)" -C "$$tmp" $(if $(4),--strip-components=$(4),);; \
		*.tar) tar -xf "$(REPOSITORY_ROOT)/$(1)" -C "$$tmp" $(if $(4),--strip-components=$(4),);; \
		*) echo "install_tool: don't know how to unpack $(1)" >&2; exit 1;; \
	esac; \
	cp "$$tmp/$(3)" "$(REPOSITORY_ROOT)/$(2)"; \
	chmod +x "$(REPOSITORY_ROOT)/$(2)"; \
	rm -rf "$$tmp"
endef
