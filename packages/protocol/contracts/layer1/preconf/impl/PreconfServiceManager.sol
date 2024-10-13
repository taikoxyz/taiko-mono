// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "../iface/IPreconfServiceManager.sol";
import "../avs-mvp/iface/ISlasher.sol";
import "../avs-mvp/iface/IAVSDirectory.sol";
import "./LibStrings.sol";

/// @dev This contract would serve as the address of the AVS w.r.t the restaking platform being
/// used.
/// Currently, this is based on a mock version of Eigenlayer that we have created solely for this
/// POC. This contract may be modified depending on the interface of the restaking contracts.
contract PreconfServiceManager is EssentialContract, IPreconfServiceManager {
    /// @dev This is currently just a flag and not actually being used to lock the stake.
    mapping(address operator => uint256 timestamp) public stakeLockedUntil;

    uint256[49] private __gap; 


       /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _preconfAddressManager The address of the {AddressManager} contract.
    function init(
        address _owner,
        address _preconfAddressManager
    )
        external
        initializer
    {
        __Essential_init(_owner, _preconfAddressManager);
    }

    /// @dev Simply relays the call to the AVS directory
    function registerOperatorToAVS(
        address operator,
        bytes calldata operatorSignature
    )
        external
        nonReentrant
        onlyFromNamed(LibStrings.B_PRECONF_REGISTRY)
    {
        IAVSDirectory.SignatureWithSaltAndExpiry memory sig =
            abi.decode(operatorSignature, (IAVSDirectory.SignatureWithSaltAndExpiry));
        IAVSDirectory(resolve("AVSDirectory", false)).registerOperatorToAVS(operator, sig);
    }

    /// @dev Simply relays the call to the AVS directory
    function deregisterOperatorFromAVS(address operator)
        external
        nonReentrant
        onlyFromNamed(LibStrings.B_PRECONF_REGISTRY)
    {
        IAVSDirectory(resolve("AVSDirectory", false)).deregisterOperatorFromAVS(operator);
    }

    /// @dev This not completely functional until Eigenlayer decides the logic of their Slasher.
    ///  for now this simply sets a value in the storage and releases an event.
    function lockStakeUntil(
        address operator,
        uint256 timestamp
    )
        external
        nonReentrant
        onlyFromNamed(LibStrings.B_PRECONF_TASK_MANAGER)
    {
        stakeLockedUntil[operator] = timestamp;
        emit StakeLockedUntil(operator, timestamp);
    }

    /// @dev This not completely functional until Eigenlayer decides the logic of their Slasher.
    function slashOperator(address operator)
        external
        nonReentrant
        onlyFromNamed(LibStrings.B_PRECONF_TASK_MANAGER)
    {
        ISlasher slasher = ISlasher(resolve(LibStrings.B_AVS_SLASHER,false));
        if (slasher.isOperatorSlashed(operator)) {
            revert OperatorAlreadySlashed();
        }
        slasher.slashOperator(operator);
    }
}
