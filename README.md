# template-go

<!-- markdownlint-disable-next-line MD033 -->
<img src="logo.png" alt="Logo" width="64" height="64" />

[![CI](https://github.com/cloudfra/template-go/actions/workflows/deploy.yaml/badge.svg)](https://github.com/cloudfra/template-go/actions/workflows/deploy.yaml) [![Go Reference](https://pkg.go.dev/badge/github.com/cloudfra/example-go.svg)](https://pkg.go.dev/github.com/cloudfra/example-go) [![codecov](https://codecov.io/gh/cloudfra/template-go/graph/badge.svg?token=UVApxhg6z7)](https://codecov.io/gh/cloudfra/template-go)

A starter template for Go projects at Cloudfra, wiring together a
`make`-based build system, cross-platform binaries, Docker images,
Terraform-based deployment, and CI so new services can skip the
boilerplate and start with working infrastructure on day one.

## Features

- **Cross-compilation** — build binaries for every supported OS/arch
  (Linux, Windows, macOS, BSDs, and more) with a single `make` invocation.
- **Docker images** — package any binary defined under `cmd/` into a
  container image.
- **Protobuf/gRPC support** — `proto.mk` and vendored `google_protobuf`
  and `grpc_gateway` definitions under `third_party/` for services that
  need RPC APIs.
- **Terraform deployment** — infrastructure-as-code under `install/terraform`
  for provisioning test and production environments.
- **CI included** — GitHub Actions workflow (`.github/workflows/deploy.yaml`)
  that builds, lints, and tests on every push and pull request.

## Getting started

```bash
# Clone the repository
git clone git@github.com:cloudfra/example-go.git
# Build binaries for every supported platform
make -j$(nproc)
# Build and run the example binary for your current platform
make run
```

## Project layout

```
cmd/<app>/       Entry point(s) for each binary (one directory per app)
internal/        Private application and library code
install/terraform/  Infrastructure-as-code for deploying the app
third_party/     Vendored protobuf/gRPC-gateway definitions
build/           Build outputs (binaries, toolchain) - not checked in
```

To add a new binary, create a new directory under `cmd/` with a `main`
package; the build system picks it up automatically.

## Common make targets

| Target | Description |
| --- | --- |
| `make` / `make all` | Build binaries for every supported platform |
| `make run` | Build and run the example binary |
| `make test` | Run the unit test suite |
| `make bench` | Run benchmarks |
| `make test-deflake` | Re-run tests to catch flakes |
| `make lint` | Run linters |
| `make protos` | Generate code from `.proto` definitions |
| `make docker-images` | Build Docker images for every app |
| `make release-binaries` | Build release artifacts for every platform |
| `make windows-binaries` | Build Windows binaries only |
| `make tf-test` | Run Terraform tests |
| `make presubmit` | Run the full suite of checks used in CI (tools, lint, build, test-deflake) |
| `make clean` | Remove build outputs |
| `make deps` / `make upgrade-deps` | Install / upgrade Go module dependencies |

## Testing

```bash
make test
make bench
```

## Deployment

Infrastructure is managed with Terraform under `install/terraform`:

```bash
cd install/terraform
terraform init
terraform plan -var=testing=true
terraform apply -var=testing=true
```

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
