#!/usr/bin/env bash
#
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

# Update the project's dependencies to their latest stable versions:
#
#   * the go directive in go.mod, to the latest Go release;
#   * Go module requirements (go get -u ./... && go mod tidy);
#   * every pinned tool version in the Makefiles. A pin is a line of the form
#     `NAME_VERSION = x.y.z` directly below a
#     `# https://github.com/OWNER/REPO/releases` comment; the latest stable
#     semver tag of OWNER/REPO wins. Pins set to `latest` are left alone.
#
# Usage: scripts/update-deps.sh

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPOSITORY_ROOT}"

MAKEFILES=(Makefile_toolchain.mk Makefile_proto.mk)

# Prints the highest stable (vX.Y.Z-style, no pre-release suffix) tag of a
# GitHub repository. git ls-remote needs no API token and, unlike the
# "latest release" API, isn't fooled by repos whose releases lag their tags.
latest_tag() {
	git ls-remote --tags --refs "https://github.com/$1" |
		sed 's#.*refs/tags/##' |
		grep -E '^v?[0-9]+(\.[0-9]+)*$' |
		sort -V |
		tail -n 1
}

# Succeeds when version $1 is strictly newer than version $2.
is_newer() {
	[ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ]
}

# Portable in-place sed (GNU and BSD/macOS).
sed_in_place() {
	local file="$1"
	shift
	sed "$@" "${file}" >"${file}.tmp"
	mv "${file}.tmp" "${file}"
}

update_go() {
	local current latest
	current="$(go mod edit -json | sed -n 's/^[[:space:]]*"Go": "\(.*\)",*$/\1/p')"
	latest="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n 1)"
	latest="${latest#go}"
	if is_newer "${latest}" "${current}"; then
		go mod edit -go="${latest}"
		echo "go: ${current} -> ${latest}"
	fi
	go get -u ./...
	go mod tidy
}

update_makefile() {
	local file="$1" repo var current tag latest
	# Emit "OWNER/REPO VAR" for each pin directly below a releases URL.
	awk '
		prev ~ /^# https:\/\/github\.com\/[^\/]+\/[^\/]+\/releases/ && $0 ~ /^[A-Z0-9_]+_VERSION *=/ {
			split(prev, url, "/")
			var = $0
			sub(/ *=.*/, "", var)
			print url[4] "/" url[5], var
		}
		{ prev = $0 }
	' "${file}" | while read -r repo var; do
		current="$(sed -n -E "s/^${var} *= *//p" "${file}")"
		if [ "${current}" = "latest" ]; then
			continue
		fi
		tag="$(latest_tag "${repo}")"
		if [ -z "${tag}" ]; then
			echo "WARNING: no stable tag found for ${repo} (${var})" >&2
			continue
		fi
		latest="${tag#v}"
		if is_newer "${latest}" "${current}"; then
			sed_in_place "${file}" -E "s/^(${var} *= *).*/\1${latest}/"
			echo "${var}: ${current} -> ${latest}"
		fi
	done
}

# install/terraform/main.tf pins required_version to TERRAFORM_VERSION's minor.
sync_terraform_required_version() {
	local main_tf="install/terraform/main.tf" version minor
	if [ ! -f "${main_tf}" ]; then
		return
	fi
	version="$(sed -n -E 's/^TERRAFORM_VERSION *= *//p' Makefile_toolchain.mk)"
	minor="$(echo "${version}" | cut -d. -f1-2)"
	sed_in_place "${main_tf}" -E "s/(required_version = \"~> )[0-9.]+\"/\1${minor}\"/"
}

update_go
for makefile in "${MAKEFILES[@]}"; do
	update_makefile "${makefile}"
done
sync_terraform_required_version
