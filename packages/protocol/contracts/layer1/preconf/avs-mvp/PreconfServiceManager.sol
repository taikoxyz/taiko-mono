// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../iface/IPreconfServiceManager.sol";
import "./iface/ISlasher.sol";
import "./iface/IAVSDirectory.sol";

/// @dev This contract would serve as the address of the AVS w.r.t the restaking platform being
/// used.
/// Currently, this is based on a mock version of Eigenlayer that we have created solely for a
/// POC.
contract PreconfServiceManager is IPreconfServiceManager, ReentrancyGuard {
    address internal immutable preconfRegistry;
    address internal immutable preconfTaskManager;
    IAVSDirectory internal immutable avsDirectory;
    ISlasher internal immutable slasher;

    /// @dev This is currently just a flag and not actually being used to lock the stake.
    mapping(address operator => uint256 timestamp) public stakeLockedUntil;

    uint256[49] private __gap; // 50 - 1

    constructor(
        address _preconfRegistry,
        address _preconfTaskManager,
        IAVSDirectory _avsDirectory,
        ISlasher _slasher
    ) {
        preconfRegistry = _preconfRegistry;
        preconfTaskManager = _preconfTaskManager;
        avsDirectory = _avsDirectory;
        slasher = _slasher;
    }

    modifier onlyCallableBy(address allowedSender) {
        if (msg.sender != allowedSender) {
            revert SenderIsNotAllowed();
        }
        _;
    }

    /// @notice Registers an operator to AVS
    /// @param operator The address of the operator to register
    /// @param operatorSignature The signature, salt, and expiry of the operator
    function registerOperatorToAVS(
        address operator,
        bytes calldata operatorSignature
    )
        external
        nonReentrant
        onlyCallableBy(preconfRegistry)
    {
        IAVSDirectory.SignatureWithSaltAndExpiry memory sig =
            abi.decode(operatorSignature, (IAVSDirectory.SignatureWithSaltAndExpiry));
        avsDirectory.registerOperatorToAVS(operator, sig);
    }

    /// @notice Deregisters an operator from AVS
    /// @param operator The address of the operator to deregister
    function deregisterOperatorFromAVS(address operator)
        external
        nonReentrant
        onlyCallableBy(preconfRegistry)
    {
        avsDirectory.deregisterOperatorFromAVS(operator);
    }

    /// @notice Locks the stake of an operator until a specified timestamp
    /// @param operator The address of the operator
    /// @param timestamp The timestamp until which the stake is locked
    function lockStakeUntil(
        address operator,
        uint256 timestamp
    )
        external
        nonReentrant
        onlyCallableBy(preconfTaskManager)
    {
        stakeLockedUntil[operator] = timestamp;
        emit StakeLockedUntil(operator, timestamp);
    }

    /// @notice Slashes an operator
    /// @param operator The address of the operator to be slashed
    function slashOperator(address operator)
        external
        nonReentrant
        onlyCallableBy(preconfTaskManager)
    {
        if (slasher.isOperatorSlashed(operator)) {
            revert OperatorAlreadySlashed();
        }
        slasher.slashOperator(operator);
    }
}
