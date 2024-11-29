// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../CommonTest.sol";
import "../helpers/CanSayHelloWorld.sol";

contract FreeMintERC1155Token is ERC1155 {
    constructor(string memory baseURI) ERC1155(baseURI) { }

    function mint(uint256 tokenId, uint256 amount) public {
        _mint(msg.sender, tokenId, amount, "");
    }
}

contract BridgedERC1155_WithHelloWorld is BridgedERC1155, CanSayHelloWorld { }

// PrankDestBridge lets us simulate a transaction to the ERC1155Vault
// from a named Bridge, without having to test/run through the real Bridge code,
// outside the scope of the unit tests in the ERC1155Vault.
contract PrankDestBridge {
    ERC1155Vault destERC1155Vault;

    struct BridgeContext {
        bytes32 msgHash;
        address sender;
        uint64 srcChainId;
    }

    BridgeContext ctx;

    constructor(ERC1155Vault _srcVault) {
        destERC1155Vault = _srcVault;
    }

    function setERC1155Vault(address addr) public {
        destERC1155Vault = ERC1155Vault(addr);
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

    function sendReceiveERC1155ToERC1155Vault(
        BaseNFTVault.CanonicalNFT calldata ctoken,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes32 msgHash,
        address srcChainERC1155Vault,
        uint64 srcChainId,
        uint256 mockLibInvokeMsgValue
    )
        public
    {
        ctx.sender = srcChainERC1155Vault;
        ctx.msgHash = msgHash;
        ctx.srcChainId = srcChainId;

        // We need this in order to 'mock' the LibBridgeInvoke's
        //  (success,retVal) =
        //     message.to.call{ value: message.value, gas: gasLimit
        // }(message.data);
        // The problem (with foundry) is that this way it is not able to deploy
        // a contract
        // most probably due to some deployment address nonce issue. (Seems a
        // known issue).
        destERC1155Vault.onMessageInvocation{ value: mockLibInvokeMsgValue }(
            abi.encode(ctoken, from, to, tokenIds, amounts)
        );

        ctx.sender = address(0);
        ctx.msgHash = bytes32(0);
        ctx.srcChainId = 0;
    }
}
