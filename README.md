# template-go

<!-- markdownlint-disable-next-line MD033 -->
<img src="logo.png" alt="Logo" width="64" height="64" />

[![CI](https://github.com/cloudfra/template-go/actions/workflows/deploy.yaml/badge.svg)](https://github.com/cloudfra/template-go/actions/workflows/deploy.yaml) [![Go Reference](https://pkg.go.dev/badge/github.com/cloudfra/template-go.svg)](https://pkg.go.dev/github.com/cloudfra/template-go) [![codecov](https://codecov.io/gh/cloudfra/template-go/graph/badge.svg?token=UVApxhg6z7)](https://codecov.io/gh/cloudfra/template-go) [![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/cloudfra/template-go/badge)](https://scorecard.dev/viewer/?uri=github.com/cloudfra/template-go)

A starter template for Go projects at Cloudfra, wiring together a
`make`-based build system, cross-platform binaries, Docker images,
Terraform-based deployment, and CI so new services can skip the
boilerplate and start with working infrastructure on day one.

## Features

- **Cross-compilation** — build binaries for every supported OS/arch
  (Linux, Windows, macOS, BSDs, and more) with a single `make` invocation.
- **Signed release binaries** — releases' Windows binaries are signed by
  [SignPath](https://signpath.io) once the repository is set up for it (see
  [Code signing](#code-signing)); otherwise `make release-binaries` signs
  what it can (all Windows architectures via Authenticode; only
  `linux/386` and `linux/amd64` via an embedded detached signature) with a
  self-signed cert generated on demand, or your own via
  `CODESIGN_CERT`/`CODESIGN_KEY`. Every other platform is copied unsigned.
- **Docker images** — package any binary defined under `cmd/` into a
  container image, either a quick single-arch build or a full
  multi-arch manifest merging every supported Linux/Windows platform.
- **Protobuf/gRPC support** — `proto.mk` and vendored `google_protobuf`
  and `grpc_gateway` definitions under `third_party/` for services that
  need RPC APIs.
- **Terraform deployment** — infrastructure-as-code under `install/terraform`
  for provisioning test and production environments.
- **CI included** — GitHub Actions workflow (`.github/workflows/deploy.yaml`)
  that builds, lints, and tests on every push and pull request, a release
  workflow (`.github/workflows/create-release.yaml`) that publishes the
  binaries and container images when a `v*` tag is pushed, and an on-demand
  one (`.github/workflows/create-temp-release.yaml`) that builds a short-lived
  release package from a `/create-temp-release` comment on a pull request
  (see [Temporary release builds](#temporary-release-builds)).
- **Enforced linting** — `make lint` runs gofmt, gofumpt, golangci-lint,
  revive, hadolint, actionlint, govulncheck, tflint/terraform fmt, and
  trivy config (Terraform misconfiguration scanning), downloading its own
  toolchain so it's reproducible locally and in CI.

## Getting started

```bash
# Clone the repository
git clone git@github.com:cloudfra/template-go.git
# Build binaries for every supported platform
make -j$(nproc)
# Build and run the exampleapp binary for your current platform
make run
```

### Starting a new project

In a repo created from this template, `scripts/template-go/init-project.sh`
replaces the template's placeholders: it sets the Go module path from the
`origin` remote, renames `cmd/exampleapp` (and `internal/exampleapp`,
`proto/exampleapp.proto`) to your binary name, and updates the Makefile,
Dockerfiles and docs to match. It finishes by running `make lint`, which
also fixes the formatting. It prompts for anything it can't infer, such as
the project description, and shows the settings for a final check before
changing anything:

```bash
scripts/template-go/init-project.sh
# or non-interactively
scripts/template-go/init-project.sh --no-confirm --app mytool --description "Does things."
```

Pass `--dry-run` to list the files it would change without touching anything.

## Project layout

```bash
cmd/<app>/          Entry point(s) for each binary (one directory per app)
internal/           Private application and library code
install/terraform/  Infrastructure-as-code for deploying the app
third_party/        Vendored protobuf/gRPC-gateway definitions
build/              Build outputs (binaries, toolchain) - not checked in
```

To add a new binary, create a new directory under `cmd/` with a `main`
package; the build system picks it up automatically.

## Common make targets

| Target                             | Description                                                                                                    |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `make` / `make all`                | Build binaries for every supported platform                                                                    |
| `make run`                         | Build and run the exampleapp binary                                                                            |
| `make test`                        | Run the unit test suite                                                                                        |
| `make bench`                       | Run benchmarks                                                                                                 |
| `make test-deflake`                | Re-run tests to catch flakes                                                                                   |
| `make lint`                        | Run the full lint suite (see Features)                                                                         |
| `make protos`                      | Generate code from `.proto` definitions                                                                        |
| `make docker-images`               | Build a quick single-arch (`linux/amd64`) Docker image per app, tagged locally                                 |
| `make scan-images`                 | Build a local single-arch image per app and scan it with trivy, failing on HIGH/CRITICAL vulnerabilities       |
| `make images`                      | Build every supported Linux/Windows platform and merge them into one multi-arch manifest per app               |
| `make linux-images windows-images` | Build just the Linux or Windows platform images that `make images` merges                                      |
| `make release-binaries`            | Build release artifacts for every platform, code-signing where supported (Windows, `linux/386`, `linux/amd64`) |
| `make windows-binaries`            | Build Windows binaries only                                                                                    |
| `make presubmit`                   | Run the full suite of checks used in CI (tools, lint, build, test-deflake)                                     |
| `make clean`                       | Remove build outputs                                                                                           |
| `make deps`                        | Install / upgrade Go module dependencies                                                                       |

## Testing

```bash
make test
make bench
```

## Simulating CI locally

[`gh act`](https://github.com/nektos/gh-act) (a `gh` CLI extension wrapping
[nektos/act](https://github.com/nektos/act)) runs this repo's actual
`.github/workflows/*.yaml` files locally in Docker, rather than
reimplementing CI's logic elsewhere:

```bash
gh extension install nektos/gh-act
gh act pull_request -W .github/workflows/reviewdog.yaml --secret GITHUB_TOKEN=$(gh auth token)
```

**Known limitations, both confirmed by hand:**

- `deploy.yaml` (the main build/lint/test pipeline) currently fails
  to parse under `act`: its schema validator doesn't yet recognize the
  `code-quality` permission scope (the same very-new GitHub Actions feature
  `make lint-yaml` already has to `-ignore` for `actionlint`), and that one
  unknown property cascades into spurious "Unknown Property" errors for the
  rest of the job. It also targets `runs-on: [self-hosted, ...]` runners,
  which `act` can't resolve without an explicit `-P <label>=<image>`
  mapping even once the schema issue is fixed.
- `reviewdog.yaml` parses and its jobs really execute (pulls the real
  action code, runs it in Docker) - but steps that call back to the GitHub
  API, like reviewdog posting check results, need a real `GITHUB_TOKEN`
  *and* correct repo/event context to fully succeed, not just the token
  shown above.

## Code signing policy

Free code signing provided by [SignPath.io](https://about.signpath.io),
certificate by [SignPath Foundation](https://signpath.org).

- Committers and reviewers: [members of the Cloudfra organization](https://github.com/orgs/cloudfra/people)
- Approvers: [owners of the Cloudfra organization](https://github.com/orgs/cloudfra/people?query=role%3Aowner)

Only binaries built by this repository's GitHub Actions workflows, from its
own source, are signed, and an approver approves each release by hand.
Changes from anyone who is not a committer are reviewed before they are
merged. Everyone on the team signs in to GitHub and SignPath with
multi-factor authentication.

Privacy: this program will not transfer any information to other networked
systems unless specifically requested by the user or the person installing
or operating it.

## Code signing

Windows binaries in a release are signed with the trusted SignPath
Foundation certificate (see [Code signing policy](#code-signing-policy)):
`.github/workflows/sign-windows.yaml` builds them on a GitHub-hosted runner
(SignPath signs nothing else for open source projects), stamped with version
information by [`go-winres`](https://github.com/tc-hib/go-winres)
(`WINDOWS_SIGNING=none`), and has SignPath sign them; `create-release.yaml`
then publishes those copies (`WINDOWS_SIGNED_DIR`) instead of signing its
own. Setting a repository up for it, once:

1. The organization's SignPath account (one for all of Cloudfra) gets a
   project named after the repository, linked to the *GitHub.com* trusted
   build system, with two signing policies: `release-signing` (the SignPath
   Foundation certificate, approved by an approver) and `test-signing`.
   Its artifact configuration is `.signpath/artifact-configuration.xml`,
   with the product name changed to the project's.
2. Repository or organization variables: `SIGNPATH_ORGANIZATION_ID`, and
   `SIGNPATH_PROJECT_SLUG` if the project's slug is not the repository's
   name. A secret: `SIGNPATH_API_TOKEN`, the token of a SignPath CI user
   that may submit to both policies.

Until `SIGNPATH_ORGANIZATION_ID` is set, nothing goes to SignPath and the
binaries are self-signed as below. A temporary release uses
`vars.SIGNPATH_TEMP_SIGNING_POLICY`, `test-signing` unless set; its
certificate is not trusted by Windows or browsers either, so set it to
`release-signing` (each build then waits for an approver) when a temporary
build has to download without warnings.

Without SignPath, `make release-binaries` code-signs the release artifacts under
`build/release/` where signing is supported, and copies everything else
unsigned:

- **Windows** (all architectures) — Authenticode-signed with `osslsigncode`.
- **`linux/386` and `linux/amd64`** — get a detached CMS/PKCS7 signature
  embedded in a `.cloudfra_signature` ELF section via `objcopy`.
- **Everything else** (the remaining Linux architectures — arm, arm64,
  mips\*, ppc\*, riscv64, loong64, s390x — plus darwin and the BSDs) is a
  plain unsigned copy. Debian/Ubuntu's `binutils` package ships `objcopy`
  built with only the x86 BFD backends, so it can't embed a signature
  section into non-x86 ELF binaries (see `LINUX_OBJCOPY_SIGNABLE_PLATFORMS`
  in the `Makefile`).

Both signing paths require `osslsigncode`, `openssl`, and `binutils`
(`objcopy`) to be installed — see the "Install Signing Dependencies" step
in `deploy.yaml` for the packages CI installs.

By default the cert/key pair is generated on demand at
`build/certs/codesign.{crt,key}` using
[`certtool`](https://github.com/cloudfra/certtool) (self-signed, fetched
automatically as part of the toolchain). To sign with your own
certificate instead, point `CODESIGN_CERT`/`CODESIGN_KEY` at existing
files:

```bash
make CODESIGN_CERT=/path/to/cert.pem CODESIGN_KEY=/path/to/key.pem release-binaries
```

## Temporary release builds

`.github/workflows/create-temp-release.yaml` ("Create Temporary Release")
builds the release package without publishing anything, so a change can be
handed to a tester or a customer before it is merged and tagged. Comment
`/create-temp-release` on a pull request, or start it manually from the
Actions tab with "Run workflow":

```bash
gh pr comment <pr> --body '/create-temp-release'
```

The job builds `build/packages/release.tar.gz` — the same target
`make release-binaries` fills, so the binaries inside are code-signed where
the platform supports it — and uploads it as the `release.tar.gz` artifact,
kept for 1 day and stored as the tarball itself rather than re-packed:

```bash
tar -xzf release.tar.gz
```

Only `linux/amd64` and `windows/amd64` are built: the workflow's `MAKEFLAGS`
clears `NICHE_PLATFORMS` and narrows `LINUX_PLATFORMS`,
`WINDOWS_PLATFORMS` and `RELEASE_PLATFORMS` to those two, which is what fits
the job's 30-minute timeout on a plain `self-hosted` Linux runner (the
`large` labels are reserved for `deploy.yaml` and `create-release.yaml`).

What it does *not* do is publish: nothing is attached to a GitHub release and
no container images are pushed, unlike the tag-triggered
`create-release.yaml`. Two things about the comment trigger are worth knowing
before relying on the artifact:

- The code it builds is the pull request that asked for it - the checkout
  step resolves `refs/pull/<n>/head` for the commented pull request, not the
  branch it was commented on. The *workflow run* is still resolved against
  the default branch, so an edit to `create-temp-release.yaml` itself only
  takes effect for comment triggers once it is merged to `main`.
- The trigger is a substring match on a newly created comment, so a comment
  quoting `/create-temp-release` in review discussion starts a run too. Since
  that run compiles the pull request's code on a self-hosted runner, the job
  only proceeds for a commenter whose `author_association` is `OWNER` or
  `MEMBER` - a member of the organization that owns the repo. An outside
  collaborator's command comment is ignored.

## Deployment

Infrastructure is managed with Terraform under `install/terraform`:

```bash
cd install/terraform
terraform init
terraform plan -var=gcp_project_id=<your-project-id> -var=testing=true
terraform apply -var=gcp_project_id=<your-project-id> -var=testing=true
```

## GitHub repository setup

`scripts/template-go/configure-github-repo.sh` applies the GitHub repository
settings this template expects (branch cleanup on merge, auto-merge, Dependabot
alerts/security updates, secret scanning, branch protection on `main`,
etc.), so a repo created from this template can be brought in line with
one command instead of clicking through Settings by hand. It infers
`OWNER/REPO` from the `origin` remote, so it's enough to just run:

```bash
scripts/template-go/configure-github-repo.sh
```

Pass `--repo OWNER/REPO` to target a different repository instead, or
`--dry-run` to print what it would change without touching anything.

It's idempotent, and settings unavailable on a given plan (e.g. branch
protection or secret scanning on a private repo without GitHub Advanced
Security) are skipped with a warning rather than failing the run.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
