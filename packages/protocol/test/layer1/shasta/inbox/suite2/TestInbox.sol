// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/layer1/shasta/impl/Inbox.sol";

/// @title TestInbox
/// @notice Test wrapper for Inbox contract with configurable behavior
/// @custom:security-contact security@taiko.xyz
contract TestInbox is Inbox {
    IInbox.Config private _config;
    bool private _configSet;
    
    function setConfig(IInbox.Config memory _newConfig) external {
        _config = _newConfig;
        _configSet = true;
    }
    
    function getConfig() public view override returns (IInbox.Config memory) {
        // Return a default config if not set (for initialization)
        if (!_configSet) {
            return IInbox.Config({
                ringBufferSize: 100,
                provingWindow: 1 hours,
                extendedProvingWindow: 2 hours,
                maxFinalizationCount: 10,
                basefeeSharingPctg: 10,
                bondToken: address(0),
                syncedBlockManager: address(0),
                proofVerifier: address(0),
                proposerChecker: address(0),
                forcedInclusionStore: address(0)
            });
        }
        return _config;
    }
    
    // Override _getBlobHash to work in test environment
    function _getBlobHash(uint256 _blobIndex) internal view override returns (bytes32) {
        // In tests, we'll use vm.blobhashes to set these
        bytes32 hash = blobhash(_blobIndex);
        // If no blob hash is set (in test environment), return a dummy hash
        if (hash == bytes32(0) && _blobIndex < 3) {
            return keccak256(abi.encode("blob", _blobIndex));
        }
        return hash;
    }
}