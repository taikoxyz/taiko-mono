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
import "../../thirdparty/LibRLPWriter.sol";

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
        console.logBytes32(mkp.header.transactionsRoot);
        console.logBytes32(mkp.header.receiptsRoot);
        console.logBytes32(mkp.header.parentHash);
        console.log(mkp.header.gasLimit);
        console.log(mkp.header.gasUsed);
        console.log(mkp.header.timestamp);
        console.log(mkp.header.nonce);
        console.log("logsbloom");
        for (uint256 i = 0; i < 8; i++) {
            console.logBytes32(mkp.header.logsBloom[i]);
        }
        console.log("hashes");
        LibTrieProof.verify(stateRoot, addr, key, value, mkp.proof);

        bytes32 signal = hashMessage(message);
        console.logBytes32(signal);
        bytes32 hashed = hashBlockHeader(mkp.header);
        console.logBytes32(hashed);
        require(
            hashed ==
                0xdf0a64a6ee6f1d7cbda07d729155fc94356fa402d9eac564515a4e20ce74d89e,
            "fail"
        );
    }

    function hashBlockHeader(BlockHeader memory header)
        internal
        pure
        returns (bytes32)
    {
        bytes[] memory list = new bytes[](15);
        list[0] = LibRLPWriter.writeHash(header.parentHash);
        list[1] = LibRLPWriter.writeHash(header.ommersHash);
        list[2] = LibRLPWriter.writeAddress(header.beneficiary);
        list[3] = LibRLPWriter.writeHash(header.stateRoot);
        list[4] = LibRLPWriter.writeHash(header.transactionsRoot);
        list[5] = LibRLPWriter.writeHash(header.receiptsRoot);
        list[6] = LibRLPWriter.writeBytes(abi.encodePacked(header.logsBloom));
        list[7] = LibRLPWriter.writeUint(header.difficulty);
        list[8] = LibRLPWriter.writeUint(header.height);
        list[9] = LibRLPWriter.writeUint64(header.gasLimit);
        list[10] = LibRLPWriter.writeUint64(header.gasUsed);
        list[11] = LibRLPWriter.writeUint64(header.timestamp);
        list[12] = LibRLPWriter.writeBytes(header.extraData);
        list[13] = LibRLPWriter.writeHash(header.mixHash);
        // According to the ethereum yellow paper, we should treat `nonce`
        // as [8]byte when hashing the block.
        list[14] = LibRLPWriter.writeBytes(abi.encodePacked(header.nonce));

        bytes memory rlpHeader = LibRLPWriter.writeList(list);
        return keccak256(rlpHeader);
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
