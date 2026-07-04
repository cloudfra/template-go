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

// Package example is the starter implementation new services should replace.
package example

import "log"

// Args holds the inputs for Run.
type Args struct {
	// File that contains the input data.
	File string
}

// Run executes the example application logic.
func Run(args Args) error {
	log.Printf("Running example with file: %s", args.File)
	return nil
}
