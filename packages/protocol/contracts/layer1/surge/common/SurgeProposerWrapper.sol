// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/IProposeBatch.sol";
import "src/layer1/based/ITaikoInbox.sol";

/// @title SurgeProposerWrapper
/// @dev Allows for managing multiple proposer and prover keys while keeping the same
/// sender in the inbox.
/// @custom:security-contact security@nethermind.io
contract SurgeProposerWrapper {
    address internal immutable taikoWrapper;
    address internal immutable taikoInbox;

    address internal admin;
    mapping(address caller => bool isAuthorized) internal authorizedCallers;

    error NotAdmin();
    error NotAuthorized();

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
        _;
    }

    modifier onlyAuthorized() {
        if (!authorizedCallers[msg.sender]) {
            revert NotAuthorized();
        }
        _;
    }

    constructor(address _admin, address _taikoWrapper, address _taikoInbox) {
        admin = _admin;
        taikoWrapper = _taikoWrapper;
        taikoInbox = _taikoInbox;
    }

    // Admin functions
    // --------------------------------------------------------------------------------------------

    function authorizeCaller(address caller) external onlyAdmin {
        authorizedCallers[caller] = true;
    }

    function deauthorizeCaller(address caller) external onlyAdmin {
        authorizedCallers[caller] = false;
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    // Authorized calls
    // --------------------------------------------------------------------------------------------

    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        onlyAuthorized
        returns (ITaikoInbox.BatchInfo memory, ITaikoInbox.BatchMetadata memory)
    {
        return IProposeBatch(taikoWrapper).proposeBatch(_params, _txList);
    }

    function proveBatches(bytes calldata _params, bytes calldata _proof) external onlyAuthorized {
        ITaikoInbox(taikoInbox).proveBatches(_params, _proof);
    }

    function depositBond(uint256 _amount) external payable onlyAuthorized {
        ITaikoInbox(taikoInbox).depositBond{ value: _amount }(_amount);
    }

    function withdrawBond(uint256 _amount) external onlyAuthorized {
        ITaikoInbox(taikoInbox).withdrawBond(_amount);
    }
}
