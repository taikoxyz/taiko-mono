#!/bin/bash

# This script generates a signed user operation for calling L1Sender.calculate
# and optionally sends it to an RPC endpoint via surge_sendUserOp.
set -e

# Private key of the owner (must match the UserOpsSubmitter owner)
export PRIVATE_KEY=${PRIVATE_KEY:-"0xeaba42282ad33c8ef2524f07277c03a776d98ae19f581990ce75becb7cfa1c23"}

# Network configuration
export FORK_URL=${FORK_URL:-"ws://45.33.84.128:32004"}

# RPC endpoint for surge_sendUserOp (optional)
export RPC_ENDPOINT=${RPC_ENDPOINT:-"http://localhost:4545"}

# UserOpsSubmitter contract address
export SUBMITTER_ADDRESS=${SUBMITTER_ADDRESS:-"0x6ee52bbf0e3c09f55fc92bf22304e8148734a484"}

# L1Sender contract address
export L1_SENDER_ADDRESS=${L1_SENDER_ADDRESS:-"0x58bE7939DB4e55bDe7aFE457EcF2F61Fb3ede864"}

# Calculation operands
export A=${A:-"20"}
export B=${B:-"5"}

# Operation: 0=ADD, 1=SUB, 2=MUL, 3=DIV
export OP=${OP:-"2"}

# Whether to send the user op to RPC
export SEND_TO_RPC=${SEND_TO_RPC:-true}

# Parameterize log level
export LOG_LEVEL=${LOG_LEVEL:-"-vvvv"}

echo "=====================================";
echo "Generating User Operation";
echo "=====================================";
echo "Submitter: $SUBMITTER_ADDRESS"
echo "L1Sender: $L1_SENDER_ADDRESS"
echo "A: $A"
echo "B: $B"
echo "OP: $OP (0=ADD, 1=SUB, 2=MUL, 3=DIV)"
echo ""

# Run the forge script and capture output
OUTPUT=$(forge script ./script/shared/surge/GenerateUserOp.s.sol:GenerateUserOp \
    --fork-url $FORK_URL \
    $LOG_LEVEL \
    --private-key $PRIVATE_KEY 2>&1)

echo "$OUTPUT"
echo ""

# Extract the hex values from output
DATA_HEX=$(echo "$OUTPUT" | grep "DATA_HEX:" | tail -1 | awk '{print $2}')
SIGNATURE_HEX=$(echo "$OUTPUT" | grep "SIGNATURE_HEX:" | tail -1 | awk '{print $2}')

echo "=====================================";
echo "Parsed Values";
echo "=====================================";
echo "Data (hex): $DATA_HEX"
echo "Signature (hex): $SIGNATURE_HEX"
echo ""

# Encode the full executeBatch calldata using cast
# executeBatch((address,uint256,bytes)[],bytes)
if [ -n "$DATA_HEX" ] && [ -n "$SIGNATURE_HEX" ]; then
    CALLDATA=$(cast calldata "executeBatch((address,uint256,bytes)[],bytes)" "[($L1_SENDER_ADDRESS,0,$DATA_HEX)]" "$SIGNATURE_HEX")
    echo "Encoded calldata: $CALLDATA"
    echo ""
fi

if [ "$SEND_TO_RPC" = "true" ] && [ -n "$CALLDATA" ]; then
    echo "=====================================";
    echo "Sending User Operation to RPC";
    echo "=====================================";
    echo "RPC Endpoint: $RPC_ENDPOINT"
    echo ""

    # Prepare JSON payload for surge_sendUserOp
    # Format matches Rust struct UserOp:
    # - submitter: Address (hex string)
    # - calldata: Bytes (hex string, full executeBatch calldata)
    JSON_PAYLOAD=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "surge_sendUserOp",
    "params": {
        "submitter": "$SUBMITTER_ADDRESS",
        "calldata": "$CALLDATA"
    },
    "id": 1
}
EOF
)

    echo "Sending request to $RPC_ENDPOINT..."
    echo "Payload:"
    echo "$JSON_PAYLOAD"
    echo ""

    # Send the request
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "$JSON_PAYLOAD" \
        "$RPC_ENDPOINT")

    echo "Response:"
    echo "$RESPONSE"
    echo ""

    echo "=====================================";
    echo "User Operation Sent";
    echo "=====================================";
else
    if [ "$SEND_TO_RPC" = "false" ]; then
        echo "Not sending to RPC (set SEND_TO_RPC=true to send)"
    else
        echo "Could not extract data or signature from output"
    fi
    echo ""
    echo "To send the user operation to RPC, use the following curl command:"
    echo ""
    cat <<EOF
curl -X POST -H "Content-Type: application/json" \\
  --data '{
    "jsonrpc": "2.0",
    "method": "surge_sendUserOp",
    "params": {
        "submitter": "$SUBMITTER_ADDRESS",
        "calldata": "$CALLDATA"
    },
    "id": 1
  }' \\
  $RPC_ENDPOINT
EOF
    echo ""
fi
