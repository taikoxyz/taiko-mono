// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/shared/bridge/IBridge.sol";

contract L2Math {
    enum OP {
        ADD,
        SUB,
        MUL,
        DIV
    }

    address public l1Sender;
    address public immutable bridge;
    uint64 public immutable l1ChainId;

    constructor(address _bridge, uint64 _l1ChainId) {
        bridge = _bridge;
        l1ChainId = _l1ChainId;
    }

    function setL1Sender(address _addr) external {
        l1Sender = _addr;
    }

    function onMessageInvocation(bytes calldata _data) external {
        require(msg.sender == bridge, "L2Math: sender is not bridge");

        // Decode the operation data
        (uint256 _a, uint256 _b, OP _op) = abi.decode(_data, (uint256, uint256, OP));

        // Perform the calculation
        uint256 result;
        if (_op == OP.ADD) {
            result = _a + _b;
        } else if (_op == OP.SUB) {
            result = _a - _b;
        } else if (_op == OP.MUL) {
            result = _a * _b;
        } else if (_op == OP.DIV) {
            result = _a / _b;
        }

        // Get the bridge context to know who sent the message
        IBridge.Context memory ctx = IBridge(bridge).context();
        require(ctx.from == l1Sender, "L2Math: ctx.from is not L1Sender");

        // Prepare the result data
        bytes memory resultData = abi.encode(result);
        bytes memory msgData = abi.encodeWithSignature("onMessageInvocation(bytes)", resultData);

        // Create the message to send back to L1
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(0),
            srcChainId: 0,
            destChainId: l1ChainId,
            srcOwner: msg.sender,
            destOwner: l1Sender,
            to: l1Sender,
            value: 0,
            fee: 0,
            gasLimit: 5_000_000,
            data: msgData
        });

        // Send the result back through the bridge
        IBridge(bridge).sendMessage(message);
    }
}
