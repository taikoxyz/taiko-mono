// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";

/// @title InboxMockContracts
/// @notice Mock contracts for testing Inbox functionality

contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    function transfer(address to, uint256 amount) external returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }
}

contract StubSyncedBlockManager {
    function saveSyncedBlock(uint48, bytes32, bytes32) external { }
}

contract StubForcedInclusionStore {
    function isOldestForcedInclusionDue() external pure returns (bool) {
        return false;
    }

    function consumeOldestForcedInclusion(address)
        external
        pure
        returns (IForcedInclusionStore.ForcedInclusion memory)
    {
        revert("Not implemented");
    }
}

contract StubProofVerifier {
    function verifyProof(bytes32, bytes calldata) external pure { }
}

contract StubProposerChecker {
    function checkProposer(address) external pure { }
}