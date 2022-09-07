#!/usr/bin/env bash
set -e

: "${TF_VERSION:=2.9.0}"
: "${TF_MAIN_REPO_DIR:=/tmp/tensorflow/tensorflow}"
: "${TF_SERVING_REPO_DIR:=/tmp/tensorflow/serving}"

clone() {
  repo_url="$1"
  repo_dir="$2"
  if [[ -e "$repo_dir" ]]; then return; fi
  mkdir -p "$repo_dir"
  git clone "$repo_url" "$repo_dir"
}

abspath() {
  if [[ "$1" =~ "tensorflow_serving" ]]; then
    echo "$TF_SERVING_REPO_DIR/$1"
  else
    echo "$TF_MAIN_REPO_DIR/$1"
  fi
}

copy_proto_and_deps() {
  src="$1"
  if ! [[ "$src" =~ ^(tensorflow|tensorflow_serving)/ ]]; then
    echo -e "\e[33mSkipping $src\e[m"
    return
  fi
  if [[ -e "$src" ]]; then
    return
  fi
  path="$(abspath "$1")"
  mkdir -p "$(dirname "$src")"
  cp "$path" "$src"
  echo "Copied $src"

  # Delete "go_package" directives and replace them with our own.
  sed -i 's/option go_package.*//' "$src"
  set_go_package "$src"

  deps=$(perl -nle 'if (/^import "(.*?\.proto)";$/) { print $1 }' < "$src")
  for dep in $deps; do
    copy_proto_and_deps "$dep"
  done
}

set_go_package() {
  src="$1"
  python3 set_go_package.py "$src"
}

clone https://github.com/tensorflow/tensorflow "$TF_MAIN_REPO_DIR"
clone https://github.com/tensorflow/serving "$TF_SERVING_REPO_DIR"

echo "Checking out TF main v$TF_VERSION"
( cd "$TF_MAIN_REPO_DIR" && git checkout "v$TF_VERSION" )
echo "Checking out TF serving $TF_VERSION"
( cd "$TF_SERVING_REPO_DIR" && git checkout "$TF_VERSION" )

rm -rf tensorflow
rm -rf tensorflow_serving

copy_proto_and_deps "tensorflow_serving/apis/prediction_service.proto"

# Now run protoc for all protos
export PATH="$PATH:$(go env GOPATH)/bin"
protoc --proto_path=. --go_out=. --go_opt=paths=source_relative --go-grpc_out=. --go-grpc_opt=paths=source_relative $(find . -type f -name '*.proto')

gazelle fix -proto=disable -go_prefix=github.com/buildbuddy-io/tensorflow-proto
go mod tidy

