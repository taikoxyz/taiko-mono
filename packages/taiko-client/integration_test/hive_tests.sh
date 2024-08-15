#!/bin/bash

if [ "$HIVE_BASE_DIR" == "" ]; then
  HIVE_BASE_DIR=/tmp/hive
  rm -rf $HIVE_BASE_DIR
  git clone git@github.com:taikoxyz/hive.git $HIVE_BASE_DIR
fi

go test -v -p=1 ./integration_test -timeout=700s
