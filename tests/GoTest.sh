#!/bin/bash -eu
#
# Copyright 2014 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

pushd "$(dirname $0)" >/dev/null
test_dir="$(pwd)"
go_path=${test_dir}/go_gen
go_test_dir=${go_path}/src/flatbufferstest
flatc=${test_dir}/../flatc

export GOPATH=$go_path

echo "GOPATH=${GOPATH}"

# Install dependent packages to $go_path
echo -n "Installing dependent packages to $GOPATH ..."
go get github.com/google/flatbuffers/go
go get golang.org/x/net/context
go get google.golang.org/grpc
echo " done"

# Emit Go code for the example schema in the test dir:
$flatc -g monster_test.fbs player_test.fbs

# Run tests with necessary flags.
# Developers may wish to see more detail by appending the verbosity flag
# -test.v to arguments for this command, as in:
#   go -test -test.v ...
# Developers may also wish to run benchmarks, which may be achieved with the
# flag -test.bench and the wildcard regexp ".":
#   go -test -test.bench=. ...
go test go_test.go \
  --test.coverpkg=github.com/google/flatbuffers/go \
  --cpp_data=monsterdata_test.mon \
  --out_data=monsterdata_go_wire.mon \
  --test.bench=. \
  --test.benchtime=3s \
  --fuzz=true \
  --fuzz_fields=4 \
  --fuzz_objects=10000

GO_TEST_RESULT=$?

if [[ $GO_TEST_RESULT  == 0 ]]; then
    echo "OK: Go tests passed."
else
    echo "KO: Go tests failed."
    exit 1
fi

echo ""

# Test under the Go directory layout
mkdir -p $go_path/src/flatbufferstest
pushd $go_path/src/flatbufferstest > /dev/null

# Emit Go code for the example schema in the flatbufferstest dir:
$flatc -g ${test_dir}/monster_test.fbs ${test_dir}/player_test.fbs

cat << EOF > go_import_test.go
package main

import (
	"testing"
	example "flatbufferstest/MyGame/Example"
	example2 "flatbufferstest/MyGame/Example2"
)

func TestImport(t *testing.T) {
	_ = example.Monster{}
	_ = example2.Player{}
}
EOF
go test go_import_test.go
GO_TEST_RESULT=$?

if [[ $GO_TEST_RESULT  == 0 ]]; then
    echo "OK: Go import tests passed."
else
    echo "KO: Go import tests failed."
    exit 1
fi

popd > /dev/null

# clean
git checkout MyGame
rm -rf $go_path

echo ""

NOT_FMT_FILES=$(gofmt -l MyGame)
if [[ ${NOT_FMT_FILES} != "" ]]; then
    echo "These files are not well gofmt'ed:\n\n${NOT_FMT_FILES}"
    # enable this when enums are properly formated
    # exit 1
fi
