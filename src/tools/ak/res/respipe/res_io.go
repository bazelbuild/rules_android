// Copyright 2022 The Bazel Authors. All rights reserved.
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


package respipe

import (
	"bufio"
	"encoding/binary"
	"io"

	"context"
	rdpb "src/tools/ak/res/proto/res_data_go_proto"
	"google.golang.org/protobuf/proto"
)

// ResInput sends all protos in the provided reader into the pipeline.
type ResInput struct {
	In io.Reader
}

// Produce returns a channel of resource protos encountered in the input along with a chan of errors encountered while decoding them.
func (ri ResInput) Produce(ctx context.Context) (<-chan *rdpb.Resource, <-chan error) {
	resC := make(chan *rdpb.Resource)
	errC := make(chan error)
	go func() {
		defer close(resC)
		defer close(errC)
		r := bufio.NewReaderSize(ri.In, 2<<16)
		var b [4]byte
		for {
			if _, err := io.ReadFull(r, b[:]); err != nil {
				if err != io.EOF {
					SendErr(ctx, errC, Errorf(ctx, "read len failed: %v", err))
				}
				return

			}
			dlen := binary.LittleEndian.Uint32(b[:])
			d := make([]byte, dlen)
			if _, err := io.ReadFull(r, d); err != nil {
				SendErr(ctx, errC, Errorf(ctx, "read proto failed: %v", err))
				return
			}
			r := &rdpb.Resource{}
			if err := proto.Unmarshal(d, r); err != nil {
				SendErr(ctx, errC, Errorf(ctx, "unmarshal proto failed: %v", err))
				return
			}
			if !SendRes(ctx, resC, r) {
				return
			}

		}

	}()
	return resC, errC
}

// ResOutput is a sink to a resource pipeline that writes all resource protos it encounters to the given writer.
type ResOutput struct {
	Out io.Writer
}

// Consume takes all resource protos from the provided channel and writes them to ResOutput's writer.
func (ro ResOutput) Consume(ctx context.Context, resChan <-chan *rdpb.Resource) <-chan error {

	errC := make(chan error)
	go func() {
		defer close(errC)

		w := bufio.NewWriterSize(ro.Out, 2<<16)
		defer func() {
			if err := w.Flush(); err != nil {
				SendErr(ctx, errC, Errorf(ctx, "flush end of data failed: %v", err))
			}
		}()
		var b [4]byte
		for r := range resChan {
			d, err := proto.Marshal(r)
			if err != nil {
				SendErr(ctx, errC, Errorf(ctx, "%#v encoding failed: %v", r, err))
				return
			}
			binary.LittleEndian.PutUint32(b[:], uint32(len(d)))
			if _, err := w.Write(b[:]); err != nil {
				SendErr(ctx, errC, Errorf(ctx, "write failed: %v", err))
				return
			}
			if _, err := w.Write(d); err != nil {
				SendErr(ctx, errC, Errorf(ctx, "write failed: %v", err))
				return
			}
		}
	}()

	return errC
}
