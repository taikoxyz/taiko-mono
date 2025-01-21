// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "src/shared/bridge/EtherBridgeWrapper.sol";
import "src/layer1/based/ITaikoInbox.sol";

contract PrankTaikoInbox {
    ITaikoInbox.Batch internal batch;

    function setBatch(ITaikoInbox.Batch memory _batch) external {
        batch = _batch;
    }

    function getBatch(uint64) external view returns (ITaikoInbox.Batch memory) {
        return batch;
    }

    function isOnL1() external pure returns (bool) {
        return true;
    }
}

contract PrankDestBridge {
    EtherBridgeWrapper destWrapper;
    TContext ctx;

    struct TContext {
        bytes32 msgHash;
        address sender;
        uint64 srcChainId;
    }

    constructor(EtherBridgeWrapper _wrapper) {
        destWrapper = _wrapper;
    }

    function context() public view returns (TContext memory) {
        return ctx;
    }

    function sendReceiveEtherToWrapper(
        address from,
        address to,
        uint256 amount,
        uint256 solverFee,
        bytes32 solverCondition,
        bytes32 msgHash,
        address srcWrapper,
        uint64 srcChainId,
        uint256 mockLibInvokeMsgValue
    )
        public
    {
        ctx.sender = srcWrapper;
        ctx.msgHash = msgHash;
        ctx.srcChainId = srcChainId;

        destWrapper.onMessageInvocation{ value: mockLibInvokeMsgValue }(
            abi.encode(from, to, amount, solverFee, solverCondition)
        );

        ctx.sender = address(0);
        ctx.msgHash = bytes32(0);
        ctx.srcChainId = 0;
    }
}
