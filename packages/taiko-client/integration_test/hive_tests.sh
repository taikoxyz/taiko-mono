#!/bin/bash

HIVE_BASE_DIR=${HIVE_BASE_DIR:-/tmp/hive}
if [ "$HIVE_BASE_DIR" == "/tmp/hive" ]; then
  rm -rf "$HIVE_BASE_DIR"
  git clone git@github.com:taikoxyz/hive.git "$HIVE_BASE_DIR"
fi

export HIVE_BASE_DIR=$HIVE_BASE_DIR && go test -v -p=1 ./integration_test -timeout=700s
