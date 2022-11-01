// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../libs/LibTrieProof.sol";
import "../../thirdparty/LibSecureMerkleTrie.sol";
import "hardhat/console.sol";

contract TestLibTrieProof {
    struct SignalProof {
        BlockHeader header;
        bytes proof;
    }

    struct BlockHeader {
        bytes32 parentHash;
        bytes32 ommersHash;
        address beneficiary;
        bytes32 stateRoot;
        bytes32 transactionsRoot;
        bytes32 receiptsRoot;
        bytes32[8] logsBloom;
        uint256 difficulty;
        uint128 height;
        uint64 gasLimit;
        uint64 gasUsed;
        uint64 timestamp;
        bytes extraData;
        bytes32 mixHash;
        uint64 nonce;
    }

    struct Message {
        uint256 id; // auto filled
        address sender; // auto filled
        uint256 srcChainId; // auto filled
        uint256 destChainId;
        address owner;
        address to; // target address on destChain
        address refundAddress; // address to refund gas/ether to, if address(0), refunds to owner
        uint256 depositValue; // value to be deposited at "to" address
        uint256 callValue; // value to be called on destChain
        uint256 processingFee; // processing fee sender is willing to pay
        uint256 gasLimit;
        bytes data; // calldata
        string memo;
    }

    function verify(
        bytes32 stateRoot,
        address addr,
        bytes32 key,
        bytes32 value,
        bytes calldata mkproof
    ) public view {
        (bytes memory accountProof, bytes memory storageProof) = abi.decode(
            mkproof,
            (bytes, bytes)
        );
        (bool exists, bytes memory rlpAccount) = LibSecureMerkleTrie.get(
            abi.encodePacked(addr),
            accountProof,
            stateRoot
        );

        require(exists, "LTP:invalid account proof");
        // LibTrieProof.verify(stateRoot, addr, key, value, mkproof);
    }

    function verify2(
        bytes32 stateRoot,
        address addr,
        bytes32 key,
        bytes32 value,
        bytes calldata mkproof,
        Message calldata message
    ) public view {
        console.log("verifyStart");
        SignalProof memory mkp = abi.decode(mkproof, (SignalProof));
        console.log("hello");
        console.logBytes32(mkp.header.stateRoot);
        LibTrieProof.verify(stateRoot, addr, key, value, mkp.proof);

        bytes32 signal = hashMessage(message);
        console.logBytes32(signal);
    }

    /**
     * @dev Hashes messages and returns the hash signed with "TAIKO_BRIDGE_MESSAGE" for verification
     */
    function hashMessage(Message memory message)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode("TAIKO_BRIDGE_MESSAGE", message));
    }
}
