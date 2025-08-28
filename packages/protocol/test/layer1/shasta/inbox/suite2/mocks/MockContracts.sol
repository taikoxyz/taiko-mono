// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/shared/based/iface/ISyncedBlockManager.sol";

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

/// @title MockSyncedBlockManager
/// @notice Mock synced block manager for testing
contract MockSyncedBlockManager is ISyncedBlockManager {
    ISyncedBlockManager.SyncedBlock public lastSyncedBlock;
    ISyncedBlockManager.SyncedBlock[] public syncedBlocks;

    function saveSyncedBlock(
        uint48 _blockNumber,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        external
    {
        lastSyncedBlock = ISyncedBlockManager.SyncedBlock({
            blockHash: _blockHash,
            stateRoot: _stateRoot,
            blockNumber: _blockNumber
        });
        syncedBlocks.push(lastSyncedBlock);
    }

    function getSyncedBlock(uint48 _offset)
        external
        view
        returns (uint48 blockNumber_, bytes32 blockHash_, bytes32 stateRoot_)
    {
        if (_offset >= syncedBlocks.length) {
            return (0, bytes32(0), bytes32(0));
        }
        ISyncedBlockManager.SyncedBlock memory syncedBlock =
            syncedBlocks[syncedBlocks.length - 1 - _offset];
        return (syncedBlock.blockNumber, syncedBlock.blockHash, syncedBlock.stateRoot);
    }

    function getLatestSyncedBlockNumber() external view returns (uint48) {
        return lastSyncedBlock.blockNumber;
    }

    function getNumberOfSyncedBlocks() external view returns (uint48) {
        return uint48(syncedBlocks.length);
    }
}
