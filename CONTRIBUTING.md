# Contributing

Thanks for contributing! This repo is meant to be forked and reused as a
template, so keeping the `make`-based workflow consistent matters — both
for this repo and every project that starts from it.

## Before you push

Run the full presubmit suite, which mirrors what CI runs on every push and
pull request:

```bash
make presubmit
```

This downloads the pinned toolchain (`tools`), runs the full lint suite
(`lint`), builds every supported platform (`all`), and re-runs the tests
under the race detector to catch flakes (`test-deflake`).

## Running checks individually

While iterating, it's usually faster to run just the piece you're
changing:

```bash
make lint   # gofmt/go vet, gofumpt, golangci-lint, revive, hadolint,
            # actionlint, govulncheck, tflint/terraform fmt
make test   # unit test suite
make run    # build and run the exampleapp binary
```

See the "Common make targets" table in the [README](README.md#common-make-targets)
for the rest (benchmarks, Terraform tests, Docker images, etc.).

## GitHub Actions workflows

Workflow YAML in this repo stays declarative: no inline scripts, and no
inline multi-line payloads. A step's `run:` invokes a committed file under
`scripts/` instead of embedding shell, and long text (PR bodies, job
descriptions) lives in a file referenced by path — for example
`.github/workflows/dependency-update.yaml` passes
`body-path: .github/dependency-update-pr-body.md` to
`peter-evans/create-pull-request` rather than inlining the body.

The reason is reviewability and debuggability: `actionlint` and
`shellcheck` only see what is inside `run:`, and a script under `scripts/`
can be run and fixed locally, while a heredoc buried in a workflow can
only be tested by pushing a commit.

### The `PULL_REQUEST_TOKEN` secret

`dependency-update.yaml` and `template-sync.yaml` open their pull requests
with `secrets.PULL_REQUEST_TOKEN`, falling back to the job's own
`GITHUB_TOKEN` when the secret is not set. That fallback is a last resort,
not the working configuration: by default an organization does not allow
workflows to create pull requests, so the step fails with `GitHub Actions
is not permitted to create or approve pull requests`. Put a GitHub App
installation token or a personal access token with `contents: write` and
`pull-requests: write` scopes in the secret, set once at the organization
level so every repo created from this template inherits it. A non-Actions
author also closes the other `GITHUB_TOKEN` limitation: a pull request
opened with it starts no workflow runs, so CI never tests it.

## Adding a new `cmd/` binary

Per the README's [Project layout](README.md#project-layout), create a new
directory under `cmd/` with a `main` package, e.g. `cmd/myapp/myapp.go`.
The build system picks it up automatically — no Makefile changes needed
to build it with `make`. To also cross-compile, package, or release it,
add its name to `ALL_APPS` in the `Makefile`.

## Coverage

Codecov enforces coverage on pull requests (see `codecov.yml`): project
coverage can drop by at most 1%, and patched code should be covered at
80% or more.
