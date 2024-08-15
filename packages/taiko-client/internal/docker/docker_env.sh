#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# check until L1 chain is ready
L1_PROBE_URL=ws://localhost:$(docker port l1_node | grep '0.0.0.0' | awk -F ':' '{print $2}')
until cast chain-id --rpc-url "$L1_PROBE_URL" 2> /dev/null; do
    sleep 1
done

# check until L2 chain is ready
L2_PROBE_URL=ws://localhost:$(docker port l2_node | grep "0.0.0.0" | awk -F ':' 'NR==2 {print $2}')
until cast chain-id --rpc-url "$L2_PROBE_URL" 2> /dev/null; do
    sleep 1
done

L1_NODE_PORT=$(docker port l1_node | grep '0.0.0.0' | awk -F ':' '{print $2}')
export L1_HTTP=http://localhost:$L1_NODE_PORT
export L1_WS=ws://localhost:$L1_NODE_PORT

export L2_HTTP=http://localhost:$(docker port l2_node | grep "0.0.0.0" | awk -F ':' 'NR==1 {print $2}')
export L2_WS=ws://localhost:$(docker port l2_node | grep "0.0.0.0" | awk -F ':' 'NR==2 {print $2}')
export L2_AUTH=http://localhost:$(docker port l2_node | grep "0.0.0.0" | awk -F ':' 'NR==3 {print $2}')
export JWT_SECRET=$DIR/nodes/jwt.hex

echo -e "L1_NODE PORTS: \n$(docker port l1_node)"
echo -e "L2_NODE PORTS: \n$(docker port l2_node)"

echo "L1_HTTP: $L1_HTTP"
echo "L1_WS: $L1_WS"
echo "L2_HTTP: $L2_HTTP"
echo "L2_WS: $L2_WS"
echo "L2_AUTH: $L2_EXECUTION_ENGINE_AUTH_ENDPOINT"
