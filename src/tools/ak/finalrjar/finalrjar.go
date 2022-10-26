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

// Package finalrjar generates a valid final R.jar.
package finalrjar

import (
	"archive/zip"
	"bufio"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
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
		Flags: []string{"package", "r_txts", "out_r_java", "root_pkg", "jdk", "jartool", "target_label"},
	}

	// Variables to hold flag values.
	pkg         string
	rtxts       string
	outputRJar  string
	rootPackage string
	jdk         string
	jartool     string
	targetLabel string

	initOnce sync.Once

	resTypes = []string{
		"anim",
		"animator",
		"array",
		"attr",
		"^attr-private",
		"bool",
		"color",
		"configVarying",
		"dimen",
		"drawable",
		"fraction",
		"font",
		"id",
		"integer",
		"interpolator",
		"layout",
		"menu",
		"mipmap",
		"navigation",
		"plurals",
		"raw",
		"string",
		"style",
		"styleable",
		"transition",
		"xml",
	}

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

type rtxtFile interface {
	io.Reader
	io.Closer
}

type resource struct {
	ID      string
	resType string
	varType string
}

func (r *resource) String() string {
	return fmt.Sprintf("{%s %s %s}", r.varType, r.resType, r.ID)
}

// Init initializes finalrjar action.
func Init() {
	initOnce.Do(func() {
		flag.StringVar(&pkg, "package", "", "Package for the R.jar")
		flag.StringVar(&rtxts, "r_txts", "", "Comma separated list of R.txt files")
		flag.StringVar(&outputRJar, "out_rjar", "", "Output R.jar path")
		flag.StringVar(&rootPackage, "root_pkg", "mi.rjava", "Package to use for root R.java")
		flag.StringVar(&jdk, "jdk", "", "Jdk path")
		flag.StringVar(&jartool, "jartool", "", "Jartool path")
		flag.StringVar(&targetLabel, "target_label", "", "The target label")
	})
}

func desc() string {
	return "finalrjar creates a platform conform R.jar from R.txt files"
}

// Run is the entry point for finalrjar. Will exit on error.
func Run() {
	if err := doWork(pkg, rtxts, outputRJar, rootPackage, jdk, jartool, targetLabel); err != nil {
		log.Fatalf("error creating final R.jar: %v", err)
	}
}

func doWork(pkg, rtxts, outputRJar, rootPackage, jdk, jartool, targetLabel string) error {
	pkgParts := strings.Split(pkg, ".")
	// Check if the package is invalid.
	if hasJavaReservedWord(pkgParts) {
		return ziputils.EmptyZip(outputRJar)
	}

	rtxtFiles, err := openRtxts(strings.Split(rtxts, ","))
	if err != nil {
		return err
	}

	resC := getIds(rtxtFiles)
	// Resources need to be grouped by type to write the R.java classes.
	resMap := groupResByType(resC)

	srcDir, err := os.MkdirTemp("", "rjar")
	if err != nil {
		return err
	}
	defer os.RemoveAll(srcDir)

	rJava, outRJava, err := createTmpRJava(srcDir, pkgParts)
	if err != nil {
		return err
	}
	defer outRJava.Close()

	rootPkgParts := strings.Split(rootPackage, ".")
	rootRJava, outRootRJava, err := createTmpRJava(srcDir, rootPkgParts)
	if err != nil {
		return err
	}
	defer outRootRJava.Close()

	if err := writeRJavas(outRJava, outRootRJava, resMap, pkg, rootPackage); err != nil {
		return err
	}

	fullRJar := filepath.Join(srcDir, "R.jar")
	if err := compileRJar([]string{rJava, rootRJava}, fullRJar, jdk, jartool, targetLabel); err != nil {
		return err
	}

	return filterZip(fullRJar, outputRJar, filepath.Join(rootPkgParts...))
}

func getIds(rtxtFiles []rtxtFile) <-chan *resource {
	// Sending all res to the same channel, even duplicates.
	resC := make(chan *resource)
	var wg sync.WaitGroup
	wg.Add(len(rtxtFiles))

	for _, file := range rtxtFiles {
		go func(file rtxtFile) {
			defer wg.Done()
			scanner := bufio.NewScanner(file)
			for scanner.Scan() {
				line := scanner.Text()
				// Each line is in the following format:
				// [int|int[]] resType resID value
				// Ex: int anim abc_fade_in 0
				parts := strings.Split(line, " ")
				if len(parts) < 3 {
					continue
				}
				// Aapt2 will sometime add resources containing the char '$'.
				// Those should be ignored - they are derived from an actual resource.
				if strings.Contains(parts[2], "$") {
					continue
				}
				resC <- &resource{ID: parts[2], resType: parts[1], varType: parts[0]}
			}
			file.Close()
		}(file)
	}

	go func() {
		wg.Wait()
		close(resC)
	}()

	return resC
}

func groupResByType(resC <-chan *resource) map[string][]*resource {
	// Set of resType.ID seen to ignore duplicates from different R.txt files.
	// Resources of different types can have the same ID, so we merge the values
	// to get a unique string. Ex: integer.btn_background_alpa
	seen := make(map[string]bool)

	// Map of resource type to list of resources.
	resMap := make(map[string][]*resource)
	for res := range resC {
		uniqueID := fmt.Sprintf("%s.%s", res.resType, res.ID)
		if _, ok := seen[uniqueID]; ok {
			continue
		}
		seen[uniqueID] = true
		resMap[res.resType] = append(resMap[res.resType], res)
	}
	return resMap
}

func writeRJavas(outRJava, outRootRJava io.Writer, resMap map[string][]*resource, pkg, rootPackage string) error {
	// The R.java points to the same resources ID in the root R.java.
	// The root R.java uses 0 or null for simplicity and does not use final fields to avoid inlining.
	// That way we can strip it from the compiled R.jar later and replace it with the real one.
	rJavaWriter := bufio.NewWriter(outRJava)
	rJavaWriter.WriteString(fmt.Sprintf("package %s;\n", pkg))
	rJavaWriter.WriteString("public class R {\n")
	rootRJavaWriter := bufio.NewWriter(outRootRJava)
	rootRJavaWriter.WriteString(fmt.Sprintf("package %s;\n", rootPackage))
	rootRJavaWriter.WriteString("public class R {\n")

	for _, resType := range resTypes {
		if resources, ok := resMap[resType]; ok {
			rJavaWriter.WriteString(fmt.Sprintf("  public static class %s {\n", resType))
			rootRJavaWriter.WriteString(fmt.Sprintf("  public static class %s {\n", resType))
			rootID := fmt.Sprintf("%s.R.%s.", rootPackage, resType)

			// Sorting resources before writing to class
			sort.Slice(resources, func(i, j int) bool {
				return resources[i].ID < resources[j].ID
			})
			for _, res := range resources {
				defaultValue := "0"
				if res.varType == "int[]" {
					defaultValue = "null"
				}
				rJavaWriter.WriteString(fmt.Sprintf("    public static final %s %s=%s%s;\n", res.varType, res.ID, rootID, res.ID))
				rootRJavaWriter.WriteString(fmt.Sprintf("    public static %s %s=%s;\n", res.varType, res.ID, defaultValue))
			}
			rJavaWriter.WriteString("  }\n")
			rootRJavaWriter.WriteString("  }\n")
		}
	}
	rJavaWriter.WriteString("}\n")
	rootRJavaWriter.WriteString("}\n")

	if err := rJavaWriter.Flush(); err != nil {
		return err
	}
	return rootRJavaWriter.Flush()
}

func createTmpRJava(srcDir string, pkgParts []string) (string, *os.File, error) {
	pkgDir := filepath.Join(append([]string{srcDir}, pkgParts...)...)
	if err := os.MkdirAll(pkgDir, 0777); err != nil {
		return "", nil, err
	}
	file := filepath.Join(pkgDir, "R.java")
	out, err := os.Create(file)
	return file, out, err
}

func openRtxts(filePaths []string) ([]rtxtFile, error) {
	var rtxtFiles []rtxtFile
	for _, filePath := range filePaths {
		in, err := os.Open(filePath)
		if err != nil {
			return nil, err
		}
		rtxtFiles = append(rtxtFiles, in)
	}
	return rtxtFiles, nil

}

func createOuput(output string) (io.Writer, error) {
	if _, err := os.Lstat(output); err == nil {
		if err := os.Remove(output); err != nil {
			return nil, err
		}
	}
	if err := os.MkdirAll(filepath.Dir(output), 0777); err != nil {
		return nil, err
	}

	return os.Create(output)
}

func filterZip(in, output, ignorePrefix string) error {
	w, err := createOuput(output)
	if err != nil {
		return err
	}

	zipOut := zip.NewWriter(w)
	defer zipOut.Close()

	zipIn, err := zip.OpenReader(in)
	if err != nil {
		return err
	}
	defer zipIn.Close()

	for _, f := range zipIn.File {
		// Ignoring the dummy root R.java.
		if strings.HasPrefix(f.Name, ignorePrefix) {
			continue
		}
		reader, err := f.Open()
		if err != nil {
			return err
		}
		if err := writeToZip(zipOut, reader, f.Name, f.Method); err != nil {
			return err
		}
		if err := reader.Close(); err != nil {
			return err
		}
	}
	return nil
}

func writeToZip(out *zip.Writer, in io.Reader, name string, method uint16) error {
	writer, err := out.CreateHeader(&zip.FileHeader{
		Name:   name,
		Method: method,
	})
	if err != nil {
		return err
	}

	if !strings.HasSuffix(name, "/") {
		if _, err := io.Copy(writer, in); err != nil {
			return err
		}
	}
	return nil
}

func compileRJar(srcs []string, rjar, jdk, jartool string, targetLabel string) error {
	control, err := os.CreateTemp("", "control")
	if err != nil {
		return err
	}
	defer os.Remove(control.Name())

	args := []string{"--javacopts",
		"-source", "8",
		"-target", "8",
		"-nowarn", "--", "--sources"}
	args = append(args, srcs...)
	args = append(args,
		"--strict_java_deps", "ERROR",
		"--output", rjar)
	if len(targetLabel) > 0 {
		args = append(args, "--target_label", targetLabel)
	}
	if _, err := fmt.Fprint(control, strings.Join(args, "\n")); err != nil {
		return err
	}
	if err := control.Sync(); err != nil {
		return err
	}
	c, err := exec.Command(jdk, "-jar", jartool, fmt.Sprintf("@%s", control.Name())).CombinedOutput()
	if err != nil {
		return fmt.Errorf("error compiling R.jar (using command: %s): %v", c, err)
	}
	return nil
}

func hasJavaReservedWord(parts []string) bool {
	for _, p := range parts {
		if javaReserved[p] {
			return true
		}
	}
	return false
}
