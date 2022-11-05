#!/bin/bash

mkdir -p ./docs/reference/smart-contracts && \
cp -r ../protocol/docs/* ./docs/reference/smart-contracts && \
cp ./scripts/_category_.json ./docs/reference/smart-contracts && \
rm -rf ./docs/reference/smart-contracts/elin ./docs/reference/smart-contracts/test ./docs/reference/smart-contracts/thirdparty ./docs/reference/smart-contracts/console.md
