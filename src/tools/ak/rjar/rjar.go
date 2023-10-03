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

// Package rjar generated R.jar.
package rjar

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"src/common/golang/ziputils"
	"src/tools/ak/types"
)

var (
	// Cmd defines the command.
	Cmd = types.Command{
		Init:  Init,
		Run:   Run,
		Desc:  desc,
		Flags: []string{"rjava", "pkgs", "rjar", "jdk", "jartool", "target_label"},
	}

	// Variables to hold flag values.
	rjava       string
	pkgs        string
	rjar        string
	jdk         string
	jartool     string
	targetLabel string

	initOnce sync.Once

	javaReserved = map[string]bool{
		"abstract":     true,
		"assert":       true,
		"boolean":      true,
		"break":        true,
		"byte":         true,
		"case":         true,
		"catch":        true,
		"char":         true,
		"class":        true,
		"const":        true,
		"continue":     true,
		"default":      true,
		"do":           true,
		"double":       true,
		"else":         true,
		"enum":         true,
		"extends":      true,
		"false":        true,
		"final":        true,
		"finally":      true,
		"float":        true,
		"for":          true,
		"goto":         true,
		"if":           true,
		"implements":   true,
		"import":       true,
		"instanceof":   true,
		"int":          true,
		"interface":    true,
		"long":         true,
		"native":       true,
		"new":          true,
		"null":         true,
		"package":      true,
		"private":      true,
		"protected":    true,
		"public":       true,
		"return":       true,
		"short":        true,
		"static":       true,
		"strictfp":     true,
		"super":        true,
		"switch":       true,
		"synchronized": true,
		"this":         true,
		"throw":        true,
		"throws":       true,
		"transient":    true,
		"true":         true,
		"try":          true,
		"void":         true,
		"volatile":     true,
		"while":        true}
)

// Init initiailizes rjar action. Must be called before google.Init.
func Init() {
	initOnce.Do(func() {
		flag.StringVar(&rjava, "rjava", "", "Input R.java path")
		flag.StringVar(&pkgs, "pkgs", "", "Packages file path")
		flag.StringVar(&rjar, "rjar", "", "Output R.jar path")
		flag.StringVar(&jdk, "jdk", "", "Jdk path")
		flag.StringVar(&jartool, "jartool", "", "Jartool path")
		flag.StringVar(&targetLabel, "target_label", "", "The target label")
	})
}

func desc() string {
	return "rjar creates the R.jar"
}

// Run is the entry point for rjar. Will exit on error.
func Run() {
	if err := doWork(rjava, pkgs, rjar, jdk, jartool, targetLabel); err != nil {
		log.Fatalf("Error creating R.jar: %v", err)
	}
}

func doWork(rjava, pkgs, rjar, jdk, jartool string, targetLabel string) error {
	f, err := os.Stat(rjava)
	if os.IsNotExist(err) || (err == nil && f.Size() == 0) {
		// If we don't have an input r_java or have an empty r_java just write
		// an empty jar apps might not define resources and in some cases (aar
		// files) its not possible to know during analysis phase, so this action
		// gets executed regardless.
		return ziputils.EmptyZip(rjar)
	}
	if err != nil {
		return fmt.Errorf("os.Stat(%s) failed: %v", rjava, err)
	}

	srcDir, err := ioutil.TempDir("", "rjar")
	if err != nil {
		return err
	}
	defer os.RemoveAll(srcDir)

	var parentPkg, subclassTmpl string
	var srcs []string

	filteredPkgs, err := getPkgs(pkgs)
	if err != nil {
		return err
	}
	for _, pkg := range filteredPkgs {
		pkgParts := strings.Split(pkg, ".")
		if hasInvalid(pkgParts) {
			continue
		}
		pkgDir := filepath.Join(append([]string{srcDir}, pkgParts...)...)
		err = os.MkdirAll(pkgDir, 0777)
		if err != nil {
			return err
		}
		outRJava := filepath.Join(pkgDir, "R.java")
		srcs = append(srcs, outRJava)
		if parentPkg == "" {
			parentPkg = pkg
			var classes []string
			out, err := os.Create(outRJava)
			if err != nil {
				return err
			}
			defer out.Close()
			in, err := os.Open(rjava)
			if err != nil {
				return err
			}
			defer in.Close()
			if _, err := fmt.Fprintf(out, "package %s;", pkg); err != nil {
				return err
			}
			if _, err := io.Copy(out, in); err != nil {
				return err
			}
			if _, err := in.Seek(0, 0); err != nil {
				return err
			}
			scanner := bufio.NewScanner(in)
			for scanner.Scan() {
				line := scanner.Text()
				if strings.Contains(line, "public static class ") {
					classes = append(classes, strings.Split(strings.Split(line, "public static class ")[1], " ")[0])
				}
			}
			subclassPts := []string{"package %s;", fmt.Sprintf("public class R extends %s.R {", pkg)}
			for _, t := range classes {
				subclassPts = append(subclassPts, fmt.Sprintf("  public static class %s extends %s.R.%s {}", t, pkg, t))
			}
			subclassPts = append(subclassPts, "}")
			subclassTmpl = strings.Join(subclassPts, "\n")
		} else {
			out, err := os.Create(outRJava)
			if err != nil {
				return err
			}
			defer out.Close()
			fmt.Fprintf(out, subclassTmpl, pkg)
		}
	}
	if _, err := os.Lstat(rjar); err == nil {
		if err := os.Remove(rjar); err != nil {
			return err
		}
	}
	if err = os.MkdirAll(filepath.Dir(rjar), 0777); err != nil {
		return err
	}
	return compileRJar(srcs, rjar, jdk, jartool, targetLabel)
}

func compileRJar(srcs []string, rjar, jdk, jartool string, targetLabel string) error {
	control, err := ioutil.TempFile("", "control")
	if err != nil {
		return err
	}
	defer os.Remove(control.Name())

	args := []string{"--javacopts",
		"-source", "8",
		"-target", "8",
		"-nowarn", "--", "--sources"}
	args = append(args, srcs...)
	args = append(args, []string{
		"--strict_java_deps", "ERROR",
		"--output", rjar,
	}...)
	if len(targetLabel) > 0 {
		// Deal with "@//"-prefixed labels (in Bazel)
		if strings.HasPrefix(targetLabel, "@//") {
			targetLabel = strings.Replace(targetLabel, "@//", "//", 1)
		}

		args = append(args, []string{
			"--target_label", targetLabel,
		}...)
	}
	if _, err := fmt.Fprint(control, strings.Join(args, "\n")); err != nil {
		return err
	}
	if err := control.Sync(); err != nil {
		return err
	}
	c, err := exec.Command(jdk, "-jar", jartool, fmt.Sprintf("@%s", control.Name())).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%v:\n%s", err, c)
	}
	return nil
}

func getPkgs(pkgs string) ([]string, error) {
	var filteredPkgs []string
	seenPkgs := map[string]bool{}

	f, err := os.Open(pkgs)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		pkg := strings.TrimSpace(scanner.Text())
		if strings.ContainsAny(pkg, "-$/") || pkg == "" {
			continue
		}
		if seenPkgs[pkg] {
			continue
		}
		filteredPkgs = append(filteredPkgs, pkg)
		seenPkgs[pkg] = true
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return filteredPkgs, nil
}

func hasInvalid(parts []string) bool {
	for _, p := range parts {
		if javaReserved[p] {
			return true
		}
	}
	return false
}
