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

# Function to convert hex string (0x...) to JSON array of bytes
# e.g., "0x0102ff" -> [1, 2, 255]
hex_to_json_array() {
    local hex_str="$1"
    # Remove 0x prefix
    hex_str="${hex_str#0x}"
    
    # Convert to JSON array using bash substring
    local json_array="["
    local first=true
    local len=${#hex_str}
    local i=0
    
    while [ $i -lt $len ]; do
        byte_hex="${hex_str:$i:2}"
        # Convert hex to decimal
        byte_dec=$((16#$byte_hex))
        
        if [ "$first" = true ]; then
            json_array="${json_array}${byte_dec}"
            first=false
        else
            json_array="${json_array},${byte_dec}"
        fi
        
        i=$((i + 2))
    done
    json_array="${json_array}]"
    
    echo "$json_array"
}

# Convert hex to JSON arrays for Vec<u8> compatibility
if [ -n "$DATA_HEX" ]; then
    DATA_ARRAY=$(hex_to_json_array "$DATA_HEX")
else
    DATA_ARRAY="[]"
fi

if [ -n "$SIGNATURE_HEX" ]; then
    SIGNATURE_ARRAY=$(hex_to_json_array "$SIGNATURE_HEX")
else
    SIGNATURE_ARRAY="[]"
fi

echo "=====================================";
echo "Parsed Values";
echo "=====================================";
echo "Data (hex): $DATA_HEX"
echo "Signature (hex): $SIGNATURE_HEX"
echo "Data (array): $DATA_ARRAY"
echo "Signature (array): $SIGNATURE_ARRAY"
echo ""

if [ "$SEND_TO_RPC" = "true" ] && [ -n "$SIGNATURE_HEX" ] && [ -n "$DATA_HEX" ]; then
    echo "=====================================";
    echo "Sending User Operation to RPC";
    echo "=====================================";
    echo "RPC Endpoint: $RPC_ENDPOINT"
    echo ""
    
    # Prepare JSON payload for surge_sendUserOp
    # Format matches Rust struct SignedUserOp:
    # - submitter: String (address)
    # - target: String (address)
    # - value: u64
    # - data: Vec<u8> (JSON array of bytes)
    # - signature: Vec<u8> (JSON array of bytes)
    # Note: jsonrpsee params.parse() expects the struct directly, not wrapped in an array
    JSON_PAYLOAD=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "surge_sendUserOp",
    "params": {
        "submitter": "$SUBMITTER_ADDRESS",
        "target": "$L1_SENDER_ADDRESS",
        "value": 0,
        "data": $DATA_ARRAY,
        "signature": $SIGNATURE_ARRAY
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
        "target": "$L1_SENDER_ADDRESS",
        "value": 0,
        "data": $DATA_ARRAY,
        "signature": $SIGNATURE_ARRAY
    },
    "id": 1
  }' \\
  $RPC_ENDPOINT
EOF
    echo ""
fi
