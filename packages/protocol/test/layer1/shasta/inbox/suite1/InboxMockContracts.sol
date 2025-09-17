// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import { LibCheckpointStore } from "contracts/layer1/shasta/libs/LibCheckpointStore.sol";
import { ICheckpointStore } from "src/shared/based/iface/ICheckpointStore.sol";

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

contract StubCheckpointProvider is ICheckpointStore {
    using LibCheckpointStore for LibCheckpointStore.Storage;

    LibCheckpointStore.Storage private _storage;
    uint16 constant MAX_HISTORY_SIZE = 10;

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

    function getLatestCheckpointNumber() external view override returns (uint48) {
        return LibCheckpointStore.getLatestCheckpointNumber(_storage);
    }

    function getNumberOfCheckpoints() external view override returns (uint48) {
        return LibCheckpointStore.getNumberOfCheckpoints(_storage);
    }
}

contract StubProofVerifier {
    bool public shouldFail;

    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }

    function verifyProof(bytes calldata, bytes calldata) external view {
        if (shouldFail) {
            revert("Invalid proof");
        }
    }
}

contract StubProposerChecker {
    function checkProposer(address) external pure { }
}
