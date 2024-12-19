// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "../helpers/CanSayHelloWorld.sol";
import "src/layer1/based/ITaikoInbox.sol";

contract BridgedERC20V2_WithHelloWorld is BridgedERC20V2, CanSayHelloWorld { }

contract PrankTaikoInbox {
    ITaikoInbox.BlockV3 internal blk;

    function setBlock(ITaikoInbox.BlockV3 memory _blk) external {
        blk = _blk;
    }

    function getBlockV3(uint64) external view returns (ITaikoInbox.BlockV3 memory) {
        return blk;
    }
}

// PrankDestBridge lets us simulate a transaction to the ERC20Vault
// from a named Bridge, without having to test/run through the real Bridge code,
// outside the scope of the unit tests in the ERC20Vault.
contract PrankDestBridge {
    ERC20Vault destERC20Vault;
    TContext ctx;

    struct TContext {
        bytes32 msgHash; // messageHash
        address sender;
        uint64 srcChainId;
    }

    constructor(ERC20Vault _erc20Vault) {
        destERC20Vault = _erc20Vault;
    }

    function setERC20Vault(address addr) public {
        destERC20Vault = ERC20Vault(addr);
    }

    function context() public view returns (TContext memory) {
        return ctx;
    }

    function sendReceiveERC20ToERC20Vault(
        ERC20Vault.CanonicalERC20 calldata canonicalToken,
        address from,
        address to,
        uint64 amount,
        uint64 solverFee,
        bytes32 solverCondition,
        bytes32 msgHash,
        address srcChainERC20Vault,
        uint64 srcChainId,
        uint256 mockLibInvokeMsgValue
    )
        public
    {
        ctx.sender = srcChainERC20Vault;
        ctx.msgHash = msgHash;
        ctx.srcChainId = srcChainId;

        // We need this in order to 'mock' the LibBridgeInvoke's
        //  (success,retVal) =
        //     message.to.call{ value: message.value, gas: gasLimit
        // }(message.data);
        // The problem (with foundry) is that this way it is not able to deploy
        // a contract most probably due to some deployment address nonce issue. (Seems a known
        // issue).
        destERC20Vault.onMessageInvocation{ value: mockLibInvokeMsgValue }(
            abi.encode(canonicalToken, from, to, amount, solverFee, solverCondition)
        );

        ctx.sender = address(0);
        ctx.msgHash = bytes32(0);
        ctx.srcChainId = 0;
    }
}
