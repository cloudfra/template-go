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

// Command example is the starter CLI entry point new services should replace.
package main

import (
	"flag"
	"log"
	"os"

	"github.com/cloudfra/template-go/internal/example"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Printf("ERROR: %s", err)
		os.Exit(1)
	}
}

// run parses args and executes the example application logic. It's split out
// from main so it can be exercised by tests without process-level exit codes
// or the flag package's global CommandLine state getting in the way.
func run(args []string) error {
	fs := flag.NewFlagSet("example", flag.ContinueOnError)
	file := fs.String("file", "", "Input File")
	if err := fs.Parse(args); err != nil {
		return err
	}

	return example.Run(example.Args{File: *file})
}
