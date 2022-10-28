pragma solidity ^0.8.9;

contract TestDecode {
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

    function decode(bytes memory proof) public pure {
        SignalProof memory mkp = abi.decode(proof, (SignalProof));
    }

    function decodeProof(bytes memory proof) public pure {
        (bytes memory accountProof, bytes memory storageProof) = abi.decode(
            proof,
            (bytes, bytes)
        );
    }

    function decodeBoth(bytes memory proof) public pure {
        SignalProof memory mkp = abi.decode(proof, (SignalProof));

        (bytes memory accountProof, bytes memory storageProof) = abi.decode(
            mkp.proof,
            (bytes, bytes)
        );
    }
}
