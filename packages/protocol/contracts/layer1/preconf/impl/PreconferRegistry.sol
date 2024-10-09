// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../shared/common/EssentialContract.sol";
import "../iface/IPreconfRegistry.sol";

/// @title Lookahead
/// @custom:security-contact security@taiko.xyz
abstract contract PreconferRegistry is IPreconfRegistry, EssentialContract {
    uint256[50] private __gap;

    error PreconferAlreadyRegistered();
    error PreconferNotRegistered();
    error InvalidValidatorSignature();
    error ValidatorSignatureExpired();
    error ValidatorAlreadyActive();
    error ValidatorAlreadyInactive();

    event PreconferRegistered(address indexed preconfer);
    event PreconferDeregistered(address indexed preconfer);
    event ValidatorAdded(bytes32 indexed pubKeyHash, address indexed preconfer);
    event ValidatorRemoved(bytes32 indexed pubKeyHash, address indexed preconfer);

    /// @notice Initializes the contract.
    function init(address _owner, address _preconfAddressManager) external initializer {
        __Essential_init(_owner, _preconfAddressManager);
    }

    function getPreconferForValidator(
        bytes32 _pubKeyHash,
        uint256 _slotTimestamp
    )
        external
        view
        returns (address)
    {
        IPreconfRegistry.Validator memory validator = getValidator(_pubKeyHash);

        // The validator is not proposing yet
        if (_slotTimestamp < validator.validSince) return address(0);

        // The validator is proposing indefinitely
        if (validator.validUntil == 0) return validator.preconfer;

        // The validator is proposing within the current slot
        if (_slotTimestamp < validator.validUntil) {
            return validator.preconfer;
        }

        return address(0);
    }

    /// @inheritdoc IPreconfRegistry
    function getValidator(bytes32 pubKeyHash) public view returns (Validator memory) { }
}
