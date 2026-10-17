// Copyright 2026 Cloudfra
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package depgate keeps subsets of this module's public API cheap to import.
//
// A project that imports only some packages of this module should only pay
// for the dependencies those packages need. Each subset below names a set
// of importable packages and the dependencies they must never reach. The
// test walks the transitive import graph that `go list -deps` reports, which
// is exactly what decides the modules `go mod tidy` adds to an importing
// project's go.mod, so no separate consumer module needs to be maintained.
//
// Build-tagged files can add imports on some platforms only, so every
// GOOS/GOARCH port is checked, with cgo on and off. In -short mode only the
// host platform is checked.
package depgate

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"maps"
	"os"
	"os/exec"
	"runtime"
	"slices"
	"strings"
	"sync"
	"testing"
)

// subset forbids every package matched by packages from depending,
// directly or transitively, on any package whose import path is, or is
// nested under, one of the deny prefixes.
type subset struct {
	name string
	// packages are `go list` patterns, e.g. "example.com/m/pkg/core/...".
	packages []string
	deny     []string
}

// heavyDeps are dependencies that are large or drag in a large tree of their
// own. Lightweight subsets must not depend on them.
var heavyDeps = []string{
	"cloud.google.com/go",
	"github.com/golang/protobuf",
	"github.com/grpc-ecosystem/grpc-gateway",
	"go.opentelemetry.io/otel",
	"google.golang.org/grpc",
	"google.golang.org/protobuf",
}

var subsets = []subset{
	{
		name:     "core",
		packages: []string{"github.com/cloudfra/template-go/pkg/core/..."},
		deny:     heavyDeps,
	},
}

// platform is a build configuration to evaluate the import graph under.
type platform struct {
	goos, goarch string
	cgo          bool
}

func (p platform) String() string {
	if p.cgo {
		return p.goos + "/" + p.goarch + "+cgo"
	}
	return p.goos + "/" + p.goarch
}

// pkg is the subset of `go list -json` output this test needs.
type pkg struct {
	ImportPath string
	Imports    []string
	DepOnly    bool
	Error      *struct{ Err string }
}

func TestDependencyGate(t *testing.T) {
	platforms, err := listPlatforms(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	for _, s := range subsets {
		t.Run(s.name, func(t *testing.T) {
			// Report a stale pattern once rather than once per platform.
			host := platform{goos: runtime.GOOS, goarch: runtime.GOARCH}
			if _, _, err := loadGraph(t.Context(), host, s.packages); err != nil {
				t.Fatal(err)
			}
			// Violation message -> platforms it occurs on.
			found := map[string][]string{}
			var errs []error
			var mu sync.Mutex
			var wg sync.WaitGroup
			for _, p := range platforms {
				wg.Go(func() {
					graph, roots, err := loadGraph(t.Context(), p, s.packages)
					mu.Lock()
					defer mu.Unlock()
					if err != nil {
						errs = append(errs, fmt.Errorf("%s: %w", p, err))
						return
					}
					for _, root := range roots {
						for _, chain := range violations(graph, root, s.deny) {
							msg := fmt.Sprintf("%s must not depend on %s:\n\t%s", root, chain[len(chain)-1], strings.Join(chain, "\n\t-> "))
							found[msg] = append(found[msg], p.String())
						}
					}
				})
			}
			wg.Wait()
			if err := errors.Join(errs...); err != nil {
				t.Fatal(err)
			}
			for _, msg := range slices.Sorted(maps.Keys(found)) {
				ps := found[msg]
				slices.Sort(ps)
				t.Errorf("%s\non %s", msg, strings.Join(ps, ", "))
			}
		})
	}
}

func TestViolations(t *testing.T) {
	graph := map[string][]string{
		"a":                                {"b", "fmt"},
		"b":                                {"google.golang.org/protobuf/proto"},
		"google.golang.org/protobuf/proto": nil,
		"fmt":                              nil,
	}
	got := violations(graph, "a", []string{"google.golang.org/protobuf"})
	if len(got) != 1 || strings.Join(got[0], " ") != "a b google.golang.org/protobuf/proto" {
		t.Errorf("violations() = %v, want [[a b google.golang.org/protobuf/proto]]", got)
	}
	if got := violations(graph, "a", []string{"google.golang.org/proto"}); len(got) != 0 {
		t.Errorf("violations() matched a partial path segment: %v", got)
	}
}

// listPlatforms returns the platforms to check: the host in -short mode,
// otherwise every port the toolchain supports.
func listPlatforms(ctx context.Context) ([]platform, error) {
	if testing.Short() {
		return []platform{{goos: runtime.GOOS, goarch: runtime.GOARCH}}, nil
	}
	out, err := goCommand(ctx, nil, "tool", "dist", "list", "-json")
	if err != nil {
		return nil, err
	}
	var ports []struct {
		GOOS, GOARCH string
		CgoSupported bool
	}
	if err := json.Unmarshal(out, &ports); err != nil {
		return nil, fmt.Errorf("cannot decode go tool dist list output, %w", err)
	}
	var platforms []platform
	for _, port := range ports {
		platforms = append(platforms, platform{goos: port.GOOS, goarch: port.GOARCH})
		if port.CgoSupported {
			platforms = append(platforms, platform{goos: port.GOOS, goarch: port.GOARCH, cgo: true})
		}
	}
	return platforms, nil
}

// loadGraph returns the import graph of patterns on p, keyed by import path,
// and the packages the patterns matched.
func loadGraph(ctx context.Context, p platform, patterns []string) (graph map[string][]string, roots []string, err error) {
	cgo := "0"
	if p.cgo {
		cgo = "1"
	}
	env := []string{"GOOS=" + p.goos, "GOARCH=" + p.goarch, "CGO_ENABLED=" + cgo}
	args := append([]string{"list", "-e", "-deps", "-json=ImportPath,Imports,DepOnly,Error"}, patterns...)
	out, err := goCommand(ctx, env, args...)
	if err != nil {
		return nil, nil, err
	}

	graph = map[string][]string{}
	var errs []error
	dec := json.NewDecoder(bytes.NewReader(out))
	for {
		var lp pkg
		if err := dec.Decode(&lp); errors.Is(err, io.EOF) {
			break
		} else if err != nil {
			return nil, nil, fmt.Errorf("cannot decode go list output, %w", err)
		}
		if lp.Error != nil {
			// A package with no files for this platform contributes no
			// imports to anyone building for it.
			if !strings.Contains(lp.Error.Err, "build constraints exclude all Go files") {
				errs = append(errs, fmt.Errorf("%s: %s", lp.ImportPath, lp.Error.Err))
			}
			continue
		}
		graph[lp.ImportPath] = lp.Imports
		if !lp.DepOnly {
			roots = append(roots, lp.ImportPath)
		}
	}
	return graph, roots, errors.Join(errs...)
}

// goCommand runs the go command with extra environment variables and returns
// its standard output.
func goCommand(ctx context.Context, env []string, args ...string) ([]byte, error) {
	// #nosec G204 -- arguments are the fixed patterns declared above.
	cmd := exec.CommandContext(ctx, "go", args...)
	cmd.Env = append(os.Environ(), env...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("go %s: %w\n%s", strings.Join(args, " "), err, stderr.String())
	}
	// go list -e reports patterns that match nothing only on stderr; a
	// subset that guards nothing is a stale rule.
	if strings.Contains(stderr.String(), "matched no packages") {
		return nil, fmt.Errorf("go %s: %s", strings.Join(args, " "), stderr.String())
	}
	return out, nil
}

// violations returns, for each denied package reachable from root, the
// shortest import chain from root to it.
func violations(graph map[string][]string, root string, deny []string) [][]string {
	parent := map[string]string{root: ""}
	queue := []string{root}
	var found [][]string
	for len(queue) > 0 {
		cur := queue[0]
		queue = queue[1:]
		if denied(cur, deny) {
			var chain []string
			for p := cur; p != ""; p = parent[p] {
				chain = append([]string{p}, chain...)
			}
			found = append(found, chain)
			continue
		}
		for _, next := range graph[cur] {
			if _, seen := parent[next]; !seen {
				parent[next] = cur
				queue = append(queue, next)
			}
		}
	}
	return found
}

func denied(path string, deny []string) bool {
	for _, d := range deny {
		if path == d || strings.HasPrefix(path, d+"/") {
			return true
		}
	}
	return false
}
