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
    uint16 constant MAX_HISTORY_SIZE = 100;

    function saveCheckpoint(ICheckpointStore.Checkpoint calldata _checkpoint) external {
        LibCheckpointStore.saveCheckpoint(_storage, _checkpoint, MAX_HISTORY_SIZE);
    }

    function getCheckpoint(uint48 _offset)
        external
        view
        override
        returns (ICheckpointStore.Checkpoint memory)
    {
        return LibCheckpointStore.getCheckpoint(_storage, _offset, MAX_HISTORY_SIZE);
    }

    function getLatestCheckpointBlockNumber() external view override returns (uint48) {
        return LibCheckpointStore.getLatestCheckpointBlockNumber(_storage);
    }

    function getNumberOfCheckpoints() external view override returns (uint48) {
        return LibCheckpointStore.getNumberOfCheckpoints(_storage);
    }
}
