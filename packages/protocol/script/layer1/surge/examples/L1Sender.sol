// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/shared/bridge/IBridge.sol";

contract L1Sender {
    enum OP {
        ADD,
        SUB,
        MUL,
        DIV
    }

    address public l2Math;
    uint256 public result;

    address public immutable bridge;
    uint64 public immutable l2ChainId;

    constructor(address _bridge, uint64 _l2ChainId) {
        bridge = _bridge;
        l2ChainId = _l2ChainId;
    }

    function setL2Math(address _addr) external {
        l2Math = _addr;
    }

    function calculate(uint256 _a, uint256 _b, OP _op) external {
        // Prepare the calldata for the L2 math contract
        bytes memory opData = abi.encode(_a, _b, _op);
        bytes memory msgData = abi.encodeWithSignature("onMessageInvocation(bytes)", opData);

        // Create the message to send to L2
        IBridge.Message memory message = IBridge.Message({
            id: 0, // Will be set by the bridge
            from: address(0), // Will be set by the bridge
            srcChainId: 0, // Will be set by the bridge
            destChainId: l2ChainId,
            srcOwner: msg.sender,
            destOwner: msg.sender,
            to: l2Math,
            value: 0,
            fee: 0,
            gasLimit: 5_000_000,
            data: msgData
        });

        // Send the message through the bridge
        IBridge(bridge).sendMessage(message);
    }

    function onMessageInvocation(bytes calldata _data) external {
        require(msg.sender == bridge, "L1Sender: sender is not the bridge");

        // Get the bridge context to know who sent the message
        IBridge.Context memory ctx = IBridge(bridge).context();
        require(ctx.from == l2Math, "L1Sender: ctx.from is not L2Math");

        // Decode and store the result
        result = abi.decode(_data, (uint256));
    }
}
