// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
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

/// @title MockProposerChecker
/// @notice Mock proposer checker that accepts all proposers
contract MockProposerChecker is IProposerChecker {
    mapping(address => bool) public authorized;

    constructor() {
        // By default, authorize test addresses created with vm.addr
        authorized[0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf] = true; // Alice = vm.addr(0x1)
        authorized[0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF] = true; // Bob = vm.addr(0x2)
        authorized[0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69] = true; // Carol = vm.addr(0x3)
    }

    function checkProposer(address _proposer) external view {
        require(authorized[_proposer], "Unauthorized proposer");
    }

    function authorizeProposer(address _proposer) external {
        authorized[_proposer] = true;
    }
}

/// @title MockForcedInclusionStore
/// @notice Mock forced inclusion store for testing
contract MockForcedInclusionStore is IForcedInclusionStore {
    ForcedInclusion[] public forcedInclusions;
    uint256[] public deadlines; // Store deadlines separately since not part of struct

    function consumeOldestForcedInclusion(address) external returns (ForcedInclusion memory) {
        if (forcedInclusions.length == 0) {
            revert("No forced inclusions");
        }
        ForcedInclusion memory inclusion = forcedInclusions[0];
        
        // Remove the first element
        for (uint256 i = 0; i < forcedInclusions.length - 1; i++) {
            forcedInclusions[i] = forcedInclusions[i + 1];
            deadlines[i] = deadlines[i + 1];
        }
        forcedInclusions.pop();
        deadlines.pop();
        
        return inclusion;
    }

    function storeForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable {
        // Create a forced inclusion from the blob reference
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.BlobSlice({
            blobHashes: new bytes32[](1),
            offset: _blobReference.offset,
            timestamp: uint48(block.timestamp)
        });
        
        ForcedInclusion memory inclusion = ForcedInclusion({
            feeInGwei: uint64(msg.value / 1 gwei),
            blobSlice: blobSlice
        });
        
        forcedInclusions.push(inclusion);
        deadlines.push(block.timestamp + 1 hours);
    }
    
    function isOldestForcedInclusionDue() external view returns (bool) {
        if (forcedInclusions.length == 0) return false;
        return block.timestamp >= deadlines[0];
    }

    function addForcedInclusion(ForcedInclusion memory _inclusion) external {
        forcedInclusions.push(_inclusion);
        deadlines.push(block.timestamp + 1 hours);
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
        ISyncedBlockManager.SyncedBlock memory block = syncedBlocks[syncedBlocks.length - 1 - _offset];
        return (block.blockNumber, block.blockHash, block.stateRoot);
    }
    
    function getLatestSyncedBlockNumber() external view returns (uint48) {
        return lastSyncedBlock.blockNumber;
    }
    
    function getNumberOfSyncedBlocks() external view returns (uint48) {
        return uint48(syncedBlocks.length);
    }
}