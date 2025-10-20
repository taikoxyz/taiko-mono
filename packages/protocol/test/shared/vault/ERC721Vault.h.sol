// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "../helpers/CanSayHelloWorld.sol";

contract BridgedERC721_WithHelloWorld is BridgedERC721, CanSayHelloWorld {
    constructor(address _resolver) BridgedERC721(_resolver) { }
}

// PrankDestBridge lets us simulate a transaction to the vault
// from a named Bridge, without having to test/run through the real Bridge code,
// outside the scope of the unit tests in the vault.
contract PrankDestBridge {
    ERC721Vault destVault;

    struct BridgeContext {
        bytes32 msgHash;
        address sender;
        uint64 chainId;
    }

    BridgeContext ctx;

    constructor(ERC721Vault _vault) {
        destVault = _vault;
    }

    function setERC721Vault(address addr) public {
        destVault = ERC721Vault(addr);
    }

    function sendMessage(IBridge.Message memory message)
        external
        payable
        returns (bytes32 msgHash, IBridge.Message memory _message)
    {
        // Dummy return value
        return (keccak256(abi.encode(message.id)), _message);
    }

    function context() public view returns (BridgeContext memory) {
        return ctx;
    }

    function sendReceiveERC721ToERC721Vault(
        BaseNFTVault.CanonicalNFT calldata canonicalToken,
        address from,
        address to,
        uint256[] memory tokenIds,
        bytes32 msgHash,
        address srcVault,
        uint64 chainId,
        uint256 mockLibInvokeMsgValue
    )
        public
    {
        ctx.sender = srcVault;
        ctx.msgHash = msgHash;
        ctx.chainId = chainId;

        // We need this in order to 'mock' the LibBridgeInvoke's
        //  (success,retVal) =
        //     message.to.call{ value: message.value, gas: gasLimit
        // }(message.data);
        // The problem (with foundry) is that this way it is not able to deploy
        // a contract
        // most probably due to some deployment address nonce issue. (Seems a
        // known issue).
        destVault.onMessageInvocation{
            value: mockLibInvokeMsgValue
        }(abi.encode(canonicalToken, from, to, tokenIds));

        ctx.sender = address(0);
        ctx.msgHash = bytes32(0);
        ctx.chainId = 0;
    }
}
