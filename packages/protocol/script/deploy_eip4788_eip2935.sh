#!/bin/bash

# Deploy the EIP-4788 (beacon block root) and EIP-2935 (historical block hashes)
# system contracts to Taiko L2 networks.
#
#   EIP-4788  0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02
#   EIP-2935  0x0000F90827F1C53a10cb7A02335B175320002935
#
# Those addresses are not chosen -- each one is CREATE(deployer, nonce=0) for a
# one-time "keyless" EOA whose private key nobody holds. The only way to land
# code there is to rebroadcast the pre-signed, pre-EIP-155 deployment
# transaction published in each EIP. PRIVATE_KEY therefore never deploys
# anything here: it only funds the keyless deployer so that its pre-signed
# transaction can pay for its own gas.
#
# Because the signature covers gasPrice (1000 gwei) and gas (250,000), the
# funding amount is fixed at exactly 0.25 ETH per contract and cannot be
# lowered. Whatever the deployment does not burn stays in the keyless EOA
# forever -- the script prints the split before broadcasting.
#
# NOTE: cast has no env-var or stdin path for a raw key, so PRIVATE_KEY is
# passed to `cast send` as an argument and is briefly visible in the process
# list while a funding transaction is in flight. Do not run the broadcast path
# on a shared machine.
#
# Both pre-signed transactions below were checked against Ethereum mainnet:
# signer, transaction hash and installed runtime bytecode are byte-identical
# to what L1 carries.

set -eo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# All three are fixed by the pre-signature and cannot be changed:
# FUND_WEI is PRESIGNED_GAS_LIMIT * GAS_PRICE_WEI.
readonly PRESIGNED_GAS_LIMIT=250000
readonly GAS_PRICE_WEI=1000000000000
readonly FUND_WEI=250000000000000000

# name|address|keyless deployer|pre-signed raw tx|runtime bytecode|init code
readonly CONTRACTS=(
"EIP-4788 beacon roots|0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02|0x0B799C86a49DEeb90402691F1041aa3AF2d3C875|0xf8838085e8d4a510008303d0908080b86a60618060095f395ff33373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff0155001b820539851b9b6eb1f0|0x3373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff015500|0x60618060095f395ff33373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff015500"
"EIP-2935 history storage|0x0000F90827F1C53a10cb7A02335B175320002935|0x3462413Af4609098e1E27A490f554f260213D685|0xf8838085e8d4a510008303d0908080b85c60538060095f395ff33373fffffffffffffffffffffffffffffffffffffffe14604657602036036042575f35600143038111604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff600143030655001b820539930aa12693182426612186309f02cfe8a80a0000|0x3373fffffffffffffffffffffffffffffffffffffffe14604657602036036042575f35600143038111604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff60014303065500|0x60538060095f395ff33373fffffffffffffffffffffffffffffffffffffffe14604657602036036042575f35600143038111604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff60014303065500"
)

# key|chain id|default rpc|explorer base
readonly NETWORKS=(
"mainnet|167000|https://rpc.mainnet.taiko.xyz|https://taikoscan.io"
"hoodi|167013|https://rpc.hoodi.taiko.xyz|https://hoodi.taikoscan.io"
)

readonly ETHERSCAN_V2_API="https://api.etherscan.io/v2/api"

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------

NETWORK=""
BROADCAST=false
ASSUME_YES=false
CHECK=false
RPC_OVERRIDE=""

usage() {
    cat << 'EOF'
Deploy EIP-4788 and EIP-2935 system contracts to Taiko L2

Usage:
  PRIVATE_KEY=0x... ./deploy_eip4788_eip2935.sh --network <mainnet|hoodi|all> [OPTIONS]

Options:
  --network <name>   mainnet (167000), hoodi (167013) or all        [required]
  --broadcast        actually fund and deploy (default: dry run only)
  --check            read-only health check: is the code there, and is the
                     execution client actually feeding it? (no transactions)
  --rpc-url <url>    override the RPC endpoint (single network only)
  --yes              skip the typed mainnet confirmation prompt
  -h, --help         show this help

Environment:
  PRIVATE_KEY        L2 funding key. Required only with --broadcast. Needs
                     0.25 ETH per contract still to deploy, plus a little for
                     the funding transactions themselves.
  ETHERSCAN_API_KEY  Etherscan V2 key. Optional: used only to cross-confirm the
                     deployed bytecode through the explorer's own node.

Notes:
  Without --broadcast the script only reads chain state and prints the plan.
  Re-running after a successful deployment is a no-op: contracts already
  carrying the canonical bytecode are reported and skipped.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --network)   NETWORK="$2"; shift 2 ;;
        --rpc-url)   RPC_OVERRIDE="$2"; shift 2 ;;
        --broadcast) BROADCAST=true; shift ;;
        --check)     CHECK=true; shift ;;
        --yes)       ASSUME_YES=true; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Exact 256-bit arithmetic. Bash integers overflow above ~9.22 ETH expressed in
# wei, which a funding wallet can easily exceed. Operands arrive from RPC
# responses, so they are parsed as integers rather than evaluated as an
# expression: a value that is not an integer aborts the run instead of being
# executed.
int_op() {
    local result
    if ! result="$(python3 -c '
import sys
try:
    op, a, b = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
except ValueError:
    sys.exit("non-integer operand")
ops = {
    "add": lambda: a + b,
    "sub": lambda: a - b,
    "mul": lambda: a * b,
    "subfloor": lambda: max(0, a - b),
    "max": lambda: max(a, b),
    "gt": lambda: int(a > b),
    "lt": lambda: int(a < b),
}
if op not in ops:
    sys.exit("unknown op " + op)
print(ops[op]())
' "$1" "$2" "$3" 2>&1)"; then
        die "arithmetic failed ($1 $2 $3): $result"
    fi
    printf '%s' "$result"
}

# Render a wei amount as ETH, for display only.
eth() { python3 -c "import sys; print(f'{int(sys.argv[1])/10**18:.6f}')" "$1"; }

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

field() { printf '%s' "$1" | cut -d'|' -f"$2"; }

die() { echo "ERROR: $*" >&2; exit 1; }

require_tools() {
    command -v cast > /dev/null 2>&1 || die "cast not found -- install Foundry (https://getfoundry.sh)"
    command -v python3 > /dev/null 2>&1 || die "python3 not found -- required for 256-bit arithmetic"
    command -v curl > /dev/null 2>&1 || die "curl not found"
}

lookup_network() {
    local key="$1" entry
    for entry in "${NETWORKS[@]}"; do
        if [[ "$(field "$entry" 1)" == "$key" ]]; then
            printf '%s' "$entry"
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# Etherscan V2 cross-check
#
# Informational only. The authoritative check is the RPC bytecode comparison
# in deploy_pending(), which has already passed by the time this runs. These
# two contracts are hand-written EVM assembly with no Solidity or Vyper
# source, so Etherscan source verification is not possible for them -- the
# API key is used purely to read the code back through a second, independent
# node.
# ---------------------------------------------------------------------------

etherscan_crosscheck() {
    local chain_id="$1" address="$2" expected="$3" body result tag value

    if [[ -z "$ETHERSCAN_API_KEY" ]]; then
        echo "      etherscan : skipped (ETHERSCAN_API_KEY not set)"
        return 0
    fi

    body="$(curl -sS -m 30 -G "$ETHERSCAN_V2_API" \
        --data-urlencode "chainid=${chain_id}" \
        --data-urlencode "module=proxy" \
        --data-urlencode "action=eth_getCode" \
        --data-urlencode "address=${address}" \
        --data-urlencode "tag=latest" \
        --data-urlencode "apikey=${ETHERSCAN_API_KEY}" 2> /dev/null)" || {
        echo "      etherscan : request failed (ignored)"
        return 0
    }

    # Tagged so an API error (bad key, rate limit) is not reported as if the
    # explorer had returned different bytecode.
    result="$(printf '%s' "$body" | python3 -c 'import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("BADJSON\t"); raise SystemExit
if not isinstance(d, dict):
    print("BADJSON\t"); raise SystemExit
if str(d.get("status")) == "0":
    print("APIERR\t" + str(d.get("result") or d.get("message") or "")); raise SystemExit
if "error" in d:
    print("APIERR\t" + str((d.get("error") or {}).get("message", ""))); raise SystemExit
print("OK\t" + str(d.get("result") or ""))' 2> /dev/null)"

    local tag="${result%%$'\t'*}" value="${result#*$'\t'}"
    case "$tag" in
        OK)
            if [[ "$(lower "$value")" == "$(lower "$expected")" ]]; then
                echo "      etherscan : bytecode confirmed via Etherscan V2"
            elif [[ -z "$value" || "$value" == "0x" ]]; then
                echo "      etherscan : explorer has not indexed the address yet -- ignored"
            else
                echo "      etherscan : MISMATCH -- explorer reports different bytecode"
                echo "                  (the RPC check above is authoritative and passed)"
            fi
            ;;
        APIERR)  echo "      etherscan : API error: ${value:-unknown} -- ignored" ;;
        *)       echo "      etherscan : unreadable response -- ignored" ;;
    esac
}

# ---------------------------------------------------------------------------
# Constants self-check
#
# Everything this script does rests on four hex blobs per contract. Re-derive
# them from the raw transaction itself -- signer, then CREATE address, then the
# runtime code the init code installs -- so a corrupted constant aborts the run
# instead of funding a keyless account that deploys something else. Offline.
# ---------------------------------------------------------------------------

verify_constants() {
    local entry name address deployer raw runtime decoded signer derived

    for entry in "${CONTRACTS[@]}"; do
        name="$(field "$entry" 1)"
        address="$(field "$entry" 2)"
        deployer="$(field "$entry" 3)"
        raw="$(field "$entry" 4)"
        runtime="$(field "$entry" 5)"

        decoded="$(cast decode-tx "$raw")" \
            || die "$name: the embedded raw transaction does not decode"

        # One pass over the decoded transaction: the gas limit and gas price it
        # was signed with must match the constants this script sizes funding
        # from, and the init code must install the runtime bytecode we expect.
        # A typo in either number would otherwise under- or over-fund
        # irreversibly. Emits the recovered signer on success.
        if ! signer="$(printf '%s' "$decoded" | python3 -c '
import json, sys
d = json.load(sys.stdin)
exp_gas, exp_price, runtime = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3].lower()
gas, price = int(d["gas"], 16), int(d["gasPrice"], 16)
if gas != exp_gas:
    sys.exit(f"signed gas limit is {gas}, but the script assumes {exp_gas}")
if price != exp_price:
    sys.exit(f"signed gas price is {price}, but the script assumes {exp_price}")
if not d["input"].lower().endswith(runtime):
    sys.exit("the init code does not install the expected runtime bytecode")
print(d["signer"])
' "$PRESIGNED_GAS_LIMIT" "$GAS_PRICE_WEI" "${runtime#0x}" 2>&1)"; then
            die "$name: $signer"
        fi

        [[ "$(lower "$signer")" == "$(lower "$deployer")" ]] \
            || die "$name: raw transaction recovers to $signer, expected $deployer"

        derived="$(cast compute-address "$signer" --nonce 0 | awk '{print $NF}')"
        [[ "$(lower "$derived")" == "$(lower "$address")" ]] \
            || die "$name: signer $signer deploys to $derived, expected $address"
    done
}

# ---------------------------------------------------------------------------
# Inspection
#
# Reads chain state and fills PENDING with the contracts that still need to be
# deployed. Never sends anything.
# ---------------------------------------------------------------------------

PENDING=()
PENDING_COUNT=0
TOTAL_FUNDING=0
TOTAL_BURN=0
TOTAL_STRANDED=0

inspect_network() {
    local rpc="$1"
    local entry name address deployer runtime initcode
    local code nonce balance shortfall gas burn basefee stranded_each funded_to

    PENDING=()
    PENDING_COUNT=0
    TOTAL_FUNDING=0
    TOTAL_BURN=0
    TOTAL_STRANDED=0

    # The pre-signature locks gasPrice at 1000 gwei; if the chain's base fee
    # ever exceeded that, the transaction could never be included. Falling back
    # to 0 on a failed query would wave that guard through and then fund a
    # keyless account whose transaction can never be mined, so this is fatal.
    if ! basefee="$(cast base-fee --rpc-url "$rpc" 2>&1)"; then
        die "cannot read the base fee from $rpc: $basefee"
    fi
    case "$basefee" in
        '' | *[!0-9]*) die "base fee from $rpc is not a number: $basefee" ;;
    esac
    if [[ "$(int_op gt "$basefee" "$GAS_PRICE_WEI")" == "1" ]]; then
        die "base fee ${basefee} wei exceeds the pre-signed gas price ${GAS_PRICE_WEI} wei"
    fi
    echo "  base fee    : ${basefee} wei (pre-signed gas price: ${GAS_PRICE_WEI} wei)"
    echo ""

    for entry in "${CONTRACTS[@]}"; do
        name="$(field "$entry" 1)"
        address="$(field "$entry" 2)"
        deployer="$(field "$entry" 3)"
        runtime="$(field "$entry" 5)"
        initcode="$(field "$entry" 6)"

        echo "  $name"
        echo "      address   : $address"

        code="$(cast code "$address" --rpc-url "$rpc")"

        if [[ "$(lower "$code")" == "$(lower "$runtime")" ]]; then
            echo "      status    : ALREADY DEPLOYED (bytecode matches) -- skipping"
            echo ""
            continue
        fi

        if [[ -n "$code" && "$code" != "0x" ]]; then
            die "$address already holds code that is NOT the canonical $name bytecode. Refusing to continue."
        fi

        nonce="$(cast nonce "$deployer" --rpc-url "$rpc")"
        if [[ "$nonce" != "0" ]]; then
            die "keyless deployer $deployer has nonce $nonce (expected 0); the pre-signed transaction can no longer be replayed on this chain"
        fi

        balance="$(cast balance "$deployer" --rpc-url "$rpc")"
        shortfall="$(int_op subfloor "$FUND_WEI" "$balance")"

        # Gas the deployment actually consumes, priced at the locked 1000 gwei.
        # A failed estimate is fatal rather than zero: it is the only pre-flight
        # proof that the creation actually executes, and treating a failure as
        # "0 gas" would understate the cost to nothing and then go on to fund
        # the keyless account irreversibly.
        if ! gas="$(cast estimate --rpc-url "$rpc" --from "$deployer" --create "$initcode" 2>&1)"; then
            die "gas estimation failed for $name: $gas"
        fi
        case "$gas" in
            '' | *[!0-9]*) die "gas estimation for $name returned a non-numeric result: $gas" ;;
        esac
        if [[ "$(int_op gt "$gas" "$PRESIGNED_GAS_LIMIT")" == "1" ]]; then
            die "$name needs $gas gas but the pre-signed transaction is fixed at $PRESIGNED_GAS_LIMIT; it would run out of gas and strand the funding"
        fi
        burn="$(int_op mul "$gas" "$GAS_PRICE_WEI")"

        echo "      deployer  : $deployer (nonce 0, balance $(eth "$balance") ETH)"
        echo "      status    : NOT DEPLOYED"
        echo "      funding   : $(eth "$shortfall") ETH to send"
        # Final balance is starting_balance + shortfall - burn, which reduces to
        # max(balance, FUND_WEI) - burn: a deployer already above FUND_WEI gets
        # no top-up and keeps the excess.
        funded_to="$(int_op max "$balance" "$FUND_WEI")"
        stranded_each="$(int_op sub "$funded_to" "$burn")"
        echo "      gas       : ${gas} -> $(eth "$burn") ETH burned, $(eth "$stranded_each") ETH stranded"
        echo ""

        PENDING[$PENDING_COUNT]="$entry|$shortfall"
        PENDING_COUNT=$((PENDING_COUNT + 1))
        TOTAL_FUNDING="$(int_op add "$TOTAL_FUNDING" "$shortfall")"
        TOTAL_BURN="$(int_op add "$TOTAL_BURN" "$burn")"
        TOTAL_STRANDED="$(int_op add "$TOTAL_STRANDED" "$stranded_each")"
    done
}

# ---------------------------------------------------------------------------
# Broadcast
# ---------------------------------------------------------------------------

deploy_pending() {
    local rpc="$1" chain_id="$2" explorer="$3"
    local i record entry shortfall name address deployer raw runtime code stranded

    i=0
    while [[ $i -lt $PENDING_COUNT ]]; do
        record="${PENDING[$i]}"
        entry="${record%|*}"
        shortfall="${record##*|}"
        name="$(field "$entry" 1)"
        address="$(field "$entry" 2)"
        deployer="$(field "$entry" 3)"
        raw="$(field "$entry" 4)"
        runtime="$(field "$entry" 5)"
        i=$((i + 1))

        echo "  --> $name"

        if [[ "$shortfall" != "0" ]]; then
            echo "      funding $deployer with $(eth "$shortfall") ETH ..."
            cast send "$deployer" \
                --value "$shortfall" \
                --rpc-url "$rpc" \
                --private-key "$PRIVATE_KEY" \
                --json > /dev/null \
                || die "funding transaction failed for $name"
            echo "      funded."
        else
            echo "      deployer already holds enough -- no funding needed."
        fi

        echo "      publishing pre-signed deployment transaction ..."
        cast publish "$raw" --rpc-url "$rpc" > /dev/null \
            || die "cast publish failed for $name -- does this RPC accept pre-EIP-155 (unprotected) transactions?"

        # Authoritative check: the code now sitting at the canonical address
        # must be byte-identical to the canonical runtime bytecode.
        code="$(cast code "$address" --rpc-url "$rpc")"
        [[ "$(lower "$code")" == "$(lower "$runtime")" ]] \
            || die "deployed bytecode at $address does not match the expected runtime bytecode"
        echo "      bytecode  : VERIFIED against canonical runtime code"

        etherscan_crosscheck "$chain_id" "$address" "$runtime"

        stranded="$(cast balance "$deployer" --rpc-url "$rpc")"
        echo "      stranded  : $(eth "$stranded") ETH left in the keyless deployer (unrecoverable)"
        echo "      explorer  : ${explorer}/address/${address}"
        echo ""
    done
}

# ---------------------------------------------------------------------------
# Health check
#
# Deploying the code is necessary but not sufficient. Both EIPs work by having
# the execution client make a system call into the contract at the start of
# every block; if the client does not make that call, the contract sits there
# with a ring buffer full of zeros. This reads, never writes.
# ---------------------------------------------------------------------------

check_network() {
    local rpc="$1"
    local head target stored actual code ts beacon
    local a2935 r2935 a4788 r4788

    a4788="$(field "${CONTRACTS[0]}" 2)"; r4788="$(field "${CONTRACTS[0]}" 5)"
    a2935="$(field "${CONTRACTS[1]}" 2)"; r2935="$(field "${CONTRACTS[1]}" 5)"

    head="$(cast block-number --rpc-url "$rpc")"

    # --- EIP-2935 -----------------------------------------------------------
    echo "  EIP-2935 history storage"
    code="$(cast code "$a2935" --rpc-url "$rpc")"
    if [[ -z "$code" || "$code" == "0x" ]]; then
        echo "      code      : NOT DEPLOYED"
    elif [[ "$(lower "$code")" != "$(lower "$r2935")" ]]; then
        echo "      code      : UNEXPECTED BYTECODE -- not the canonical contract"
    else
        echo "      code      : deployed ($(( (${#code} - 2) / 2 )) bytes)"
        # The system call at block N stores blockhash(N-1), so head-1 is the
        # freshest slot and the only one guaranteed to post-date a deployment
        # that just happened. An older slot may predate the contract and would
        # read as empty even on a client that is behaving correctly.
        target=$((head - 1))
        stored="$(cast call "$a2935" \
            "$(cast to-uint256 "$target")" --rpc-url "$rpc" 2> /dev/null || echo "0x")"
        actual="$(cast block "$target" --rpc-url "$rpc" --json \
            | python3 -c 'import json, sys; print(json.load(sys.stdin)["hash"])')"
        if [[ "$stored" == "$actual" ]]; then
            echo "      ring buf  : LIVE -- block $target hash matches"
        else
            echo "      ring buf  : not populated at block $target"
            echo "                  expected $actual, got $stored"
            echo "                  if the contract was only just deployed, wait a"
            echo "                  block and re-run; if it stays empty the client"
            echo "                  is making no EIP-2935 system call"
        fi
    fi
    echo ""

    # --- EIP-4788 -----------------------------------------------------------
    echo "  EIP-4788 beacon roots"
    code="$(cast code "$a4788" --rpc-url "$rpc")"
    if [[ -z "$code" || "$code" == "0x" ]]; then
        echo "      code      : NOT DEPLOYED"
    elif [[ "$(lower "$code")" != "$(lower "$r4788")" ]]; then
        echo "      code      : UNEXPECTED BYTECODE -- not the canonical contract"
    else
        echo "      code      : deployed ($(( (${#code} - 2) / 2 )) bytes)"
        ts="$(cast block latest --rpc-url "$rpc" --json \
            | python3 -c 'import json, sys; print(int(json.load(sys.stdin)["timestamp"], 16))')"
        stored="$(cast call "$a4788" \
            "$(cast to-uint256 "$ts")" --rpc-url "$rpc" 2> /dev/null || echo "0x")"
        echo "      stored    : $stored"
    fi

    # The contract can only ever hold what the header carries.
    beacon="$(cast block latest --rpc-url "$rpc" --json \
        | python3 -c 'import json, sys; print(json.load(sys.stdin).get("parentBeaconBlockRoot", "<absent>"))')"
    echo "      header    : parentBeaconBlockRoot = $beacon"
    case "$beacon" in
        0x0000000000000000000000000000000000000000000000000000000000000000)
            echo "                  header field is zero, so this contract can only ever"
            echo "                  return zero on this chain (L2 has no beacon chain)" ;;
        "<absent>")
            echo "                  header field absent -- nothing can populate this contract" ;;
    esac
    echo ""
}

run_network() {
    local key="$1" entry chain_id rpc explorer funder funder_balance reply
    local gas_price margin required actual_chain_id

    entry="$(lookup_network "$key")" || die "unknown network '$key'"
    chain_id="$(field "$entry" 2)"
    rpc="${RPC_OVERRIDE:-$(field "$entry" 3)}"
    explorer="$(field "$entry" 4)"

    echo "============================================================"
    echo " Taiko $key  (chain id $chain_id)"
    echo "============================================================"
    echo "  rpc         : $rpc"

    # Asserted here rather than inside inspect_network so that --check cannot
    # silently report on the wrong chain via --rpc-url.
    actual_chain_id="$(cast chain-id --rpc-url "$rpc")" || die "cannot reach RPC $rpc"
    [[ "$actual_chain_id" == "$chain_id" ]] \
        || die "$rpc reports chain id $actual_chain_id, expected $chain_id"
    echo ""

    if [[ "$CHECK" == true ]]; then
        check_network "$rpc"
        return 0
    fi

    inspect_network "$rpc"

    if [[ $PENDING_COUNT -eq 0 ]]; then
        echo "  Nothing to do: both contracts are already deployed."
        echo ""
        return 0
    fi

    echo "  ---- totals ----"
    echo "  funding to send : $(eth "$TOTAL_FUNDING") ETH (leaves your wallet)"
    echo "  burned as gas   : $(eth "$TOTAL_BURN") ETH"
    echo "  stranded        : $(eth "$TOTAL_STRANDED") ETH (left in the keyless EOAs, unrecoverable)"
    echo ""

    if [[ "$BROADCAST" != true ]]; then
        echo "  DRY RUN -- nothing was sent. Re-run with --broadcast to deploy."
        echo ""
        return 0
    fi

    [[ -n "$PRIVATE_KEY" ]] || die "PRIVATE_KEY is required with --broadcast"

    funder="$(cast wallet address --private-key "$PRIVATE_KEY")"
    funder_balance="$(cast balance "$funder" --rpc-url "$rpc")"
    echo "  funder      : $funder ($(eth "$funder_balance") ETH)"

    # cast send needs gas on top of the value it forwards, so a wallet holding
    # exactly TOTAL_FUNDING would deploy the first contract and then fail on the
    # second. Reserve a generous margin (21k gas x10 per funding transaction) so
    # a shortfall stops the run before anything is sent.
    gas_price="$(cast gas-price --rpc-url "$rpc")"
    margin="$(int_op mul "$gas_price" 210000)"
    margin="$(int_op mul "$margin" "$PENDING_COUNT")"
    required="$(int_op add "$TOTAL_FUNDING" "$margin")"
    if [[ "$(int_op lt "$funder_balance" "$required")" == "1" ]]; then
        die "funder holds $(eth "$funder_balance") ETH but $(eth "$required") ETH is needed ($(eth "$TOTAL_FUNDING") funding + $(eth "$margin") gas margin)"
    fi

    if [[ "$key" == "mainnet" && "$ASSUME_YES" != true ]]; then
        echo ""
        echo "  *** This spends real ETH on Taiko mainnet and cannot be undone. ***"
        read -r -p "  Type 'taiko-mainnet' to proceed: " reply
        [[ "$reply" == "taiko-mainnet" ]] || die "confirmation failed -- aborted"
    fi

    echo ""
    deploy_pending "$rpc" "$chain_id" "$explorer"
    echo "  Done."
    echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    require_tools

    if [[ "$CHECK" == true && "$BROADCAST" == true ]]; then
        die "--check is read-only and cannot be combined with --broadcast"
    fi

    verify_constants

    if [[ -z "$NETWORK" ]]; then
        echo "ERROR: --network is required" >&2
        echo "" >&2
        usage >&2
        exit 1
    fi

    if [[ "$NETWORK" == "all" ]]; then
        [[ -z "$RPC_OVERRIDE" ]] || die "--rpc-url cannot be combined with --network all"
        run_network "mainnet"
        run_network "hoodi"
    else
        lookup_network "$NETWORK" > /dev/null || die "unknown network '$NETWORK' (expected mainnet, hoodi or all)"
        run_network "$NETWORK"
    fi
}

main
