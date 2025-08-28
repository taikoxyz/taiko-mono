// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/shared/based/iface/ICheckpointManager.sol";

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

/// @title MockCheckpointManager
/// @notice Mock synced block manager for testing
contract MockCheckpointManager is ICheckpointManager {
    ICheckpointManager.Checkpoint public lastCheckpoint;
    ICheckpointManager.Checkpoint[] public checkpoints;

    function saveCheckpoint(ICheckpointManager.Checkpoint calldata _checkpoint) external {
        checkpoints.push(_checkpoint);
    }

    function getCheckpoint(uint48 _offset)
        external
        view
        returns (ICheckpointManager.Checkpoint memory)
    {
        ICheckpointManager.Checkpoint memory checkpoint;
        if (_offset < checkpoints.length) {
            checkpoint = checkpoints[checkpoints.length - 1 - _offset];
        }
        return checkpoint;
    }

    function getLatestCheckpointNumber() external view returns (uint48) {
        return lastCheckpoint.blockNumber;
    }

    function getNumberOfCheckpoints() external view returns (uint48) {
        return uint48(checkpoints.length);
    }
}
