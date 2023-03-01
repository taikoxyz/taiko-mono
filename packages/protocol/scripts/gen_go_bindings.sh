#!/bin/bash

# Generate go contract bindings.
# ref: https://geth.ethereum.org/docs/dapp/native-bindings

set -eou pipefail

script_dir="$(realpath "$(dirname $0)")"
protocol_dir="$(realpath "${script_dir}/..")"
go_bindings_dir=$(realpath "${protocol_dir}/bindings")
abigen=$TAIKO_GETH_DIR/build/bin/abigen

function compile_abigen() {
    if [ -f "${abigen}" ]; then
        return
    fi
    echo "File \"${abigen}\" not exists, need to compile"
}

function compile_protocol() {
    cd "${protocol_dir}" &&
        pnpm install &&
        pnpm clean &&
        pnpm compile &&
        cd -
}

function extract_abi_json() {
    l1_abi_json="${script_dir}/l1_abi.json"
    l2_abi_json="${script_dir}/l2_abi.json"
    jq .abi "${protocol_dir}/artifacts/contracts/L1/TaikoL1.sol/TaikoL1.json" >"${l1_abi_json}"
    jq .abi "${protocol_dir}/artifacts/contracts/L2/TaikoL2.sol/TaikoL2.json" >"${l2_abi_json}"
}

function gen_go_bindings() {
    ${abigen} --abi "${l1_abi_json}" --type TaikoL1Client --abi "${l2_abi_json}" --type TaikoL2Client --pkg bindings --out "${go_bindings_dir}/contract.go"
    cd "${go_bindings_dir}"
    go mod tidy
}

function clean() {
    rm "${l1_abi_json}" "${l2_abi_json}"
}

echo ""
echo "Start generating go contract bindings..."
echo ""

compile_abigen
compile_protocol
extract_abi_json
gen_go_bindings
clean

echo "🍻 Go contract bindings generated!"
