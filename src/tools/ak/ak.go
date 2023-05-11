// Copyright 2018 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// AK (Android Kit) is a command line tool that combines useful commands.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"sort"

	_ "src/common/golang/flagfile"
	"src/tools/ak/akcommands"
	"src/tools/ak/types"
)

const helpHeader = "AK Android Kit is a command line tool that combines useful commands.\n\nUsage: ak %s <options>\n\n"

var (
	cmds = akcommands.Cmds
)

func helpDesc() string {
	return "Prints help for commands, or the index."
}

func main() {
	cmds["help"] = types.Command{
		Init: func() {},
		Run:  printHelp,
		Desc: helpDesc,
	}

	switch len(os.Args) {
	case 1:
		printHelp()
	case 3:
		if os.Args[1] == "help" {
			cmdHelp(os.Args[2])
			os.Exit(0)
		}
		fallthrough
	default:
		cmd := os.Args[1]
		if _, present := cmds[cmd]; present {
			runCmd(cmd)
		} else {
			log.Fatalf("Command %q not found. Try 'ak help'.", cmd)
		}
	}
}

func runCmd(cmd string) {
	cmds[cmd].Init()
	flag.CommandLine.Parse(os.Args[2:])
	cmds[cmd].Run()
}

func printHelp() {
	fmt.Printf(helpHeader, "<command>")
	printCmds()
	fmt.Println("\nGetting more help:")
	fmt.Println("  ak help <command>")
	fmt.Println("             Prints help and options for <command>.")
}

func printCmds() {
	fmt.Println("Available commands:")
	var keys []string
	for k := range cmds {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		fmt.Printf("  %-10s %v\n", k, cmds[k].Desc())
	}
}

func cmdHelp(cmd string) {
	if _, present := cmds[cmd]; present {
		cmds[cmd].Init()
		fmt.Printf(helpHeader, cmd)
		fmt.Println(cmds[cmd].Desc())
		if cmds[cmd].Flags != nil {
			fmt.Println("\nOptions:")
			for _, f := range cmds[cmd].Flags {
				fmt.Println(flagDesc(f))
			}
		}
	} else {
		fmt.Printf("Command %q not found.\n\n", cmd)
		printCmds()
	}
}

func flagDesc(name string) string {
	flag := flag.Lookup(name)
	if flag == nil {
		return fmt.Sprintf("Flag %q not found!", name)
	}
	flagType := fmt.Sprintf("%T", flag.Value)
	flagType = flagType[6 : len(flagType)-5]
	return fmt.Sprintf("  -%-16s %s (a %s; default: \"%s\")", flag.Name, flag.Usage, flagType, flag.DefValue)
}
