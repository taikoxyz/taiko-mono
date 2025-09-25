// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/layer1/shasta/iface/IProofVerifier.sol";
import { LibCheckpointStore } from "src/shared/shasta/libs/LibCheckpointStore.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";

/// @title MockERC20
/// @notice Mock ERC20 token for testing bond mechanics
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title MockProofVerifier
/// @notice Mock proof verifier that always accepts proofs
contract MockProofVerifier is IProofVerifier {
    function verifyProof(bytes32, bytes calldata) external pure {
        // Always accept
    }
}

/// @title MockCheckpointProvider
/// @notice Mock checkpoint provider for testing
contract MockCheckpointProvider is ICheckpointStore {
    using LibCheckpointStore for LibCheckpointStore.Storage;

    LibCheckpointStore.Storage private _storage;

    function saveCheckpoint(ICheckpointStore.Checkpoint calldata _checkpoint) external override {
        LibCheckpointStore.saveCheckpoint(_storage, _checkpoint);
    }

    function getLatestCheckpointBlockNumber() external view override returns (uint48) {
        return LibCheckpointStore.getLatestCheckpointBlockNumber(_storage);
    }

    function getCheckpoint(uint48 _blockNumber)
        external
        view
        override
        returns (ICheckpointStore.Checkpoint memory)
    {
        return LibCheckpointStore.getCheckpoint(_storage, _blockNumber);
    }

    function getCheckpointHash(uint48 _blockNumber) external view override returns (bytes32) {
        ICheckpointStore.Checkpoint memory checkpoint = LibCheckpointStore.getCheckpoint(_storage, _blockNumber);
        return checkpoint.blockHash;
    }
}
