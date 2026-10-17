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

// Package depgate fails the build when a guarded package picks up a
// forbidden dependency, directly or transitively.
//
// Unlike a depguard lint rule, which only inspects the import statements of
// the files it matches, this walks the full import graph reported by
// `go list -deps`, so a forbidden package pulled in three hops away is
// caught too, along with the chain of imports that brought it in.
package depgate

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"os/exec"
	"strings"
	"testing"
)

// rule forbids every package in roots from depending on any package whose
// import path is, or is nested under, one of the deny prefixes.
type rule struct {
	name  string
	roots []string
	deny  []string
}

// heavyDeps are dependencies that are large or drag in a large tree of their
// own. Packages that are meant to stay lightweight must not depend on them.
var heavyDeps = []string{
	"cloud.google.com/go",
	"github.com/golang/protobuf",
	"github.com/grpc-ecosystem/grpc-gateway",
	"go.opentelemetry.io/otel",
	"google.golang.org/grpc",
	"google.golang.org/protobuf",
}

var rules = []rule{
	{
		name: "core packages stay lightweight",
		roots: []string{
			"github.com/cloudfra/template-go/internal",
			"github.com/cloudfra/template-go/internal/exampleapp",
		},
		deny: heavyDeps,
	},
}

// pkg is the subset of `go list -json` output this test needs.
type pkg struct {
	ImportPath string
	Imports    []string
}

func TestDependencyGate(t *testing.T) {
	for _, r := range rules {
		t.Run(r.name, func(t *testing.T) {
			graph := loadGraph(t, r.roots)
			for _, root := range r.roots {
				for _, chain := range violations(graph, root, r.deny) {
					t.Errorf("%s must not depend on %s:\n\t%s", root, chain[len(chain)-1], strings.Join(chain, "\n\t-> "))
				}
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

// loadGraph returns the import graph rooted at roots, keyed by import path.
func loadGraph(t *testing.T, roots []string) map[string][]string {
	t.Helper()
	args := append([]string{"list", "-deps", "-json=ImportPath,Imports"}, roots...)
	// #nosec G204 -- arguments are the fixed package lists declared above.
	cmd := exec.CommandContext(t.Context(), "go", args...)
	out, err := cmd.Output()
	if err != nil {
		if exitErr, ok := errors.AsType[*exec.ExitError](err); ok {
			t.Fatalf("go list failed: %v\n%s", err, exitErr.Stderr)
		}
		t.Fatalf("go list failed: %v", err)
	}
	graph := map[string][]string{}
	dec := json.NewDecoder(bytes.NewReader(out))
	for {
		var p pkg
		if err := dec.Decode(&p); errors.Is(err, io.EOF) {
			break
		} else if err != nil {
			t.Fatalf("cannot decode go list output: %v", err)
		}
		graph[p.ImportPath] = p.Imports
	}
	for _, root := range roots {
		if _, ok := graph[root]; !ok {
			t.Fatalf("root package %s not found; update the rules in this test", root)
		}
	}
	return graph
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
