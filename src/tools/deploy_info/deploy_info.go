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

// Tool to generate the deploy_info.pb that ASwB needs in order to deploy apps.
package main

import (
	"flag"
	"io/ioutil"
	"log"

	_ "src/common/golang/flagfile"
	"src/common/golang/flags"
	pb "src/tools/deploy_info/proto/android_deploy_info_go_proto"
	"google.golang.org/protobuf/proto"
)

var apk = flags.NewStringList("apk", "Path to the apk(s).")
var manifest = flag.String("manifest", "", "Path to the Android manifest.")
var deployInfo = flag.String("deploy_info", "", "Deploy info pb output path")

func main() {
	flag.Parse()

	if *apk == nil {
		log.Fatalf("-apk needs to be specified.")
	}

	if *manifest == "" {
		log.Fatalf("-manifest needs to be specified.")
	}

	if *deployInfo == "" {
		log.Fatalf("-deploy_info needs to be specified.")
	}

	manifestArtifact := &pb.Artifact{ExecRootPath: *manifest}
	splitArtifacts := []*pb.Artifact{}
	for _, split := range *apk {
		splitArtifacts = append(splitArtifacts, &pb.Artifact{ExecRootPath: split})
	}

	info := &pb.AndroidDeployInfo{
		MergedManifest: manifestArtifact,
		ApksToDeploy:   splitArtifacts}
	bits, err := proto.Marshal(info)
	if err != nil {
		log.Fatal(err)
	}
	if err := ioutil.WriteFile(*deployInfo, bits, 0644); err != nil {
		log.Fatal(err)
	}
}
