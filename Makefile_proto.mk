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

# https://github.com/grpc/grpc-go/releases
GOLANG_GRPC_VERSION = 1.6.2
# https://github.com/protocolbuffers/protobuf-go/releases
GOLANG_PROTOBUF_VERSION = 1.36.12
# https://github.com/grpc-ecosystem/grpc-gateway/releases
GRPC_GATEWAY_VERSION = 2.32.0
# https://github.com/protocolbuffers/protobuf/releases
PROTOC_VERSION = 36.2

ifeq ($(OS),Windows_NT)
	PROTOC_PACKAGE = https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-win64.zip
else
	ifeq ($(UNAME_S),Linux)
		ifeq ($(UNAME_ARCH),arm)
			PROTOC_PACKAGE = https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-linux-aarch_64.zip
		else
			PROTOC_PACKAGE = https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-linux-x86_64.zip
		endif
	endif
	ifeq ($(UNAME_S),Darwin)
		PROTOC_PACKAGE = https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-osx-x86_64.zip
	endif
endif

# Installed into TOOLCHAIN_CACHE like the Makefile_toolchain.mk tools. The
# protoc archive is kept there too: the third_party rules below vendor its
# include files.
PROTOC_ARCHIVE = $(call cache_path,protoc,$(PROTOC_VERSION),$(PROTOC_PACKAGE))
PROTOC_BIN = $(call tool_path,protoc,$(PROTOC_VERSION))
PROTOC_GEN_GO = $(call tool_path,protoc-gen-go,$(GOLANG_PROTOBUF_VERSION))
PROTOC_GEN_GO_GRPC = $(call tool_path,protoc-gen-go-grpc,$(GOLANG_GRPC_VERSION))
PROTOC_GEN_GRPC_GATEWAY = $(call tool_path,protoc-gen-grpc-gateway,$(GRPC_GATEWAY_VERSION))
PROTOC_GEN_OPENAPIV2 = $(call tool_path,protoc-gen-openapiv2,$(GRPC_GATEWAY_VERSION))

PROTOC := GOPATH="$(TOOLCHAIN_DIR)" "$(PROTOC_BIN)"
PROTOC_INCLUDE_FLAGS = -I "$(REPOSITORY_ROOT)" -I "$(THIRDPARTY_DIR)/grpc_gateway/include/" -I "$(THIRDPARTY_DIR)/google_protobuf/include/"

# protoc otherwise resolves each protoc-gen-* plugin by searching PATH, which
# depends on the toolchain bin directory being on PATH in whatever form the
# current OS/shell expects (this breaks on the Windows CI runner). Pointing
# protoc at each plugin's exact path sidesteps PATH entirely.
PROTOC_GO_PLUGIN = --plugin=protoc-gen-go="$(PROTOC_GEN_GO)"
PROTOC_GO_GRPC_PLUGIN = --plugin=protoc-gen-go-grpc="$(PROTOC_GEN_GO_GRPC)"
PROTOC_GRPC_GATEWAY_PLUGIN = --plugin=protoc-gen-grpc-gateway="$(PROTOC_GEN_GRPC_GATEWAY)"
PROTOC_OPENAPIV2_PLUGIN = --plugin=protoc-gen-openapiv2="$(PROTOC_GEN_OPENAPIV2)"

PROTOC_TOOLCHAIN = $(PROTOC_BIN) $(PROTOC_GEN_GO_GRPC) $(PROTOC_GEN_GO) $(PROTOC_GEN_GRPC_GATEWAY) $(PROTOC_GEN_OPENAPIV2)
# The vendored include trees protoc compiles against. Depended on by the
# compile rules below rather than by the plugins, which do not read them: they
# are rebuilt whenever their master-branch archives are missing from build/,
# and that must not make the cached plugins look out of date.
PROTOC_INCLUDES = third_party/google_protobuf/include/google/LICENSE third_party/grpc_gateway/include/protoc-gen-openapiv2/LICENSE

$(PROTOC_ARCHIVE):
	mkdir -p "$(dir $@)"
	$(call DOWNLOAD,$(PROTOC_PACKAGE))

$(PROTOC_BIN): $(PROTOC_ARCHIVE)
	$(call INSTALL_FROM_ARCHIVE,$(PROTOC_ARCHIVE))

$(PROTOC_GEN_GO_GRPC):
	$(call GO_INSTALL_TOOL,google.golang.org/grpc/cmd/protoc-gen-go-grpc@v$(GOLANG_GRPC_VERSION))

$(PROTOC_GEN_GO):
	$(call GO_INSTALL_TOOL,google.golang.org/protobuf/cmd/protoc-gen-go@v$(GOLANG_PROTOBUF_VERSION))

$(PROTOC_GEN_GRPC_GATEWAY):
	$(call GO_INSTALL_TOOL,github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@v$(GRPC_GATEWAY_VERSION))

$(PROTOC_GEN_OPENAPIV2):
	$(call GO_INSTALL_TOOL,github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@v$(GRPC_GATEWAY_VERSION))

build/archives/googleapis.zip:
	mkdir -p "$(dir $@)"
	$(CURL) -o "$(ARCHIVES_DIR)/googleapis.zip" -L \
		"https://github.com/googleapis/googleapis/archive/master.zip"
	touch "$(REPOSITORY_ROOT)/$@"

build/archives/grpc-gateway.zip:
	mkdir -p "$(dir $@)"
	$(CURL) -o "$(ARCHIVES_DIR)/grpc-gateway.zip" -L \
		"https://github.com/grpc-ecosystem/grpc-gateway/archive/master.zip"
	touch "$(REPOSITORY_ROOT)/$@"

third_party/google_protobuf/include/google/: third_party/google_protobuf/include/google/LICENSE
	touch "$(REPOSITORY_ROOT)/$@"

third_party/google_protobuf/include/google/LICENSE: $(PROTOC_ARCHIVE) build/archives/googleapis.zip
	rm -rf "$(THIRDPARTY_DIR)/google_protobuf/include/"
	mkdir -p "$(TOOLCHAIN_DIR)/googleapis-temp/"
	mkdir -p "$(THIRDPARTY_DIR)/google_protobuf/include/google/"
	# Copy protobuf
	cp "$(PROTOC_ARCHIVE)" "$(TOOLCHAIN_DIR)/googleapis-temp/protoc.zip"
	cp "$(ARCHIVES_DIR)/googleapis.zip" "$(TOOLCHAIN_DIR)/googleapis-temp/"
	(cd "$(TOOLCHAIN_DIR)/googleapis-temp/"; unzip -q -o protoc.zip)
	cp -rf "$(TOOLCHAIN_DIR)/googleapis-temp/include/google/"* \
		"$(THIRDPARTY_DIR)/google_protobuf/include/google/"

	# Copy google/apis
	(cd $(TOOLCHAIN_DIR)/googleapis-temp/; unzip -q -o googleapis.zip)
	mkdir -p "$(THIRDPARTY_DIR)/google_protobuf/include/google/api/"
	mkdir -p "$(THIRDPARTY_DIR)/google_protobuf/include/google/rpc/"
	mkdir -p "$(THIRDPARTY_DIR)/google_protobuf/include/google/longrunning/"
	cp -rf "$(TOOLCHAIN_DIR)/googleapis-temp/googleapis-master/google/api/"* \
		"$(THIRDPARTY_DIR)/google_protobuf/include/google/api/"
	cp -rf "$(TOOLCHAIN_DIR)/googleapis-temp/googleapis-master/google/rpc/"* \
		"$(THIRDPARTY_DIR)/google_protobuf/include/google/rpc/"
	cp -rf "$(TOOLCHAIN_DIR)/googleapis-temp/googleapis-master/google/longrunning/"* \
		"$(THIRDPARTY_DIR)/google_protobuf/include/google/longrunning/"
	cp -f "$(TOOLCHAIN_DIR)/googleapis-temp/googleapis-master/LICENSE" \
		"$(THIRDPARTY_DIR)/google_protobuf/include/google/LICENSE"
	$(FIND) "$(THIRDPARTY_DIR)/google_protobuf/include/google/" -type f -name '*BUILD.bazel' -exec rm {} +
	rm -rf "$(TOOLCHAIN_DIR)/googleapis-temp"
	touch "$(REPOSITORY_ROOT)/$@"

third_party/grpc_gateway/include/protoc-gen-openapiv2/: third_party/grpc_gateway/include/protoc-gen-openapiv2/LICENSE
	touch "$(REPOSITORY_ROOT)/$@"

third_party/grpc_gateway/include/protoc-gen-openapiv2/LICENSE: build/archives/grpc-gateway.zip
	rm -rf "$(THIRDPARTY_DIR)/grpc_gateway/"
	mkdir -p "$(TOOLCHAIN_DIR)/grpc-gateway-temp/"
	mkdir -p "$(THIRDPARTY_DIR)/grpc_gateway/include/protoc-gen-openapiv2/options/"

	cp "$(ARCHIVES_DIR)/grpc-gateway.zip" "$(TOOLCHAIN_DIR)/grpc-gateway-temp/"
	(cd "$(TOOLCHAIN_DIR)/grpc-gateway-temp/"; unzip -q -o grpc-gateway.zip)
	cp -rf "$(TOOLCHAIN_DIR)/grpc-gateway-temp/grpc-gateway-main/protoc-gen-openapiv2/options/"*.proto \
		"$(THIRDPARTY_DIR)/grpc_gateway/include/protoc-gen-openapiv2/options/"
	cp -f "$(TOOLCHAIN_DIR)/grpc-gateway-temp/grpc-gateway-main/LICENSE" \
		"$(THIRDPARTY_DIR)/grpc_gateway/include/protoc-gen-openapiv2/LICENSE"
	$(FIND) "$(THIRDPARTY_DIR)/grpc_gateway/include/protoc-gen-openapiv2/" -type f -name '*BUILD.bazel' -exec rm {} +
	rm -rf "$(TOOLCHAIN_DIR)/grpc-gateway-temp"
	touch "$(REPOSITORY_ROOT)/$@"

%_grpc.pb.go: %.proto %.pb.go $(PROTOC_TOOLCHAIN) $(PROTOC_INCLUDES)
	$(PROTOC) $(PROTOC_INCLUDE_FLAGS) $(PROTOC_GO_GRPC_PLUGIN) --go-grpc_out=. --go-grpc_opt=paths=source_relative $<
	$(TOOLCHAIN_GO) fmt $@
	touch "$(REPOSITORY_ROOT)/$@"

%.pb.go: %.proto $(PROTOC_TOOLCHAIN) $(PROTOC_INCLUDES)
	$(PROTOC) $(PROTOC_INCLUDE_FLAGS) $(PROTOC_GO_PLUGIN) --go_out=. --go_opt=paths=source_relative $<
	$(TOOLCHAIN_GO) fmt $@
	touch "$(REPOSITORY_ROOT)/$@"

%.pb.gw.go: %.proto %_grpc.pb.go $(PROTOC_TOOLCHAIN) $(PROTOC_INCLUDES)
	echo $(dir $<)
	$(PROTOC) $(PROTOC_INCLUDE_FLAGS) $(PROTOC_GRPC_GATEWAY_PLUGIN) --grpc-gateway_out . --grpc-gateway_opt paths=source_relative --grpc-gateway_opt logtostderr=true --grpc-gateway_opt allow_delete_body=true $<
	$(SED_REPLACE) 's/proto_0/proto/g' $@
	$(SED_REPLACE) 's/status_0/status/g' $@
	$(TOOLCHAIN_GO) fmt $@
	touch "$(REPOSITORY_ROOT)/$@"

%.swagger.json: %.proto %.pb.gw.go $(PROTOC_TOOLCHAIN) $(PROTOC_INCLUDES)
	$(PROTOC) $(PROTOC_INCLUDE_FLAGS) $(PROTOC_OPENAPIV2_PLUGIN) --openapiv2_out . --openapiv2_opt logtostderr=true $<
	touch "$(REPOSITORY_ROOT)/$@"
