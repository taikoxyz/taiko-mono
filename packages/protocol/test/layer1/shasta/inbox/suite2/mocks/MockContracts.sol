// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import { LibCheckpoints } from "src/layer1/shasta/libs/LibCheckpoints.sol";
import "contracts/shared/based/iface/ICheckpointProvider.sol";

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
contract MockCheckpointProvider is ICheckpointProvider {
    using LibCheckpoints for LibCheckpoints.Storage;
    
    LibCheckpoints.Storage private _storage;
    
    constructor() {
        _storage.init(100);
    }

    function saveCheckpoint(LibCheckpoints.Checkpoint calldata _checkpoint) external override {
        _storage.saveCheckpoint(_checkpoint);
    }

    function getCheckpoint(uint48 _offset)
        external
        view
        override
        returns (LibCheckpoints.Checkpoint memory)
    {
        return _storage.getCheckpoint(_offset);
    }

    function getLatestCheckpointNumber() external view override returns (uint48) {
        return _storage.getLatestCheckpointNumber();
    }

    function getNumberOfCheckpoints() external view override returns (uint48) {
        return _storage.getNumberOfCheckpoints();
    }
}
