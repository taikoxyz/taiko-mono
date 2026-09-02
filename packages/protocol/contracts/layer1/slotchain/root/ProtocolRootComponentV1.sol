// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    IProtocolRootActivationV1
} from "../../../shared/slotchain/iface/IProtocolRootActivationV1.sol";
import { ProtocolRootCreate3ProxyV1 } from "./ProtocolRootCreate3ProxyV1.sol";

/// @title Shared protocol root activation state
/// @notice Keeps a root component nonfunctional until its pinned factory activates the campaign.
/// @dev Derived role constructors must pass their compile-time role in the closed interval 1..9.
/// @custom:security-contact security@taiko.xyz
abstract contract ProtocolRootComponentV1 is IProtocolRootActivationV1 {
    bytes4 internal constant PROTOCOL_ROOT_ACTIVATION_MAGIC = 0x50524131; // PRA1
    bytes4 internal constant PROTOCOL_ROOT_ACTIVATED_MAGIC = 0x52414131; // RAA1

    uint8 internal constant PROTOCOL_ROOT_INACTIVE = 0;
    uint8 internal constant PROTOCOL_ROOT_ACTIVE = 1;

    address internal immutable _protocolRootFactory;

    // These cross-artifact commitments deliberately remain constructor-written writerless storage.
    bytes32 private _protocolRootFactoryRuntimeHash;
    bytes32 private _protocolRootCampaignKey;
    uint8 private _protocolRootActivationState;

    /// @dev Validates the CREATE3 deployment topology without reading any not-yet-deployed peer.
    /// @param _factory The root factory that CREATE2-deployed the one-shot proxy.
    /// @param _factoryRuntimeHash The manifest-pinned factory runtime hash.
    /// @param _campaignKey The code-independent campaign key.
    /// @param _role The derived contract's compile-time role in the root manifest.
    constructor(
        address _factory,
        bytes32 _factoryRuntimeHash,
        bytes32 _campaignKey,
        uint8 _role
    ) {
        if (
            _factory == address(0) || _factoryRuntimeHash == bytes32(0)
                || _campaignKey == bytes32(0) || _role == 0 || _role > 9
        ) {
            revert InvalidProtocolRootActivationConfig();
        }
        if (_runtimeHash(_factory) != _factoryRuntimeHash) revert ProtocolRootFactoryCodeChanged();

        bytes32 salt = keccak256(
            abi.encodePacked("slot-chain-protocol-root-component-v1", _campaignKey, _role)
        );
        address expectedProxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            _factory,
                            salt,
                            keccak256(type(ProtocolRootCreate3ProxyV1).creationCode)
                        )
                    )
                )
            )
        );
        if (msg.sender != expectedProxy || address(this) != _createNonceOneAddress(expectedProxy)) {
            revert InvalidProtocolRootDeployment();
        }

        _protocolRootFactory = _factory;
        _protocolRootFactoryRuntimeHash = _factoryRuntimeHash;
        _protocolRootCampaignKey = _campaignKey;
    }

    /// @inheritdoc IProtocolRootActivationV1
    function protocolRootActivationV1()
        external
        view
        returns (bytes4 magic_, address protocolRootFactory_, bytes32 campaignKey_, uint8 state_)
    {
        return (
            PROTOCOL_ROOT_ACTIVATION_MAGIC,
            _protocolRootFactory,
            _protocolRootCampaignKey,
            _protocolRootActivationState
        );
    }

    /// @inheritdoc IProtocolRootActivationV1
    function activateProtocolRootV1(bytes32 _campaignKey) external returns (bytes4 magic_) {
        if (
            msg.sender != _protocolRootFactory
                || _runtimeHash(msg.sender) != _protocolRootFactoryRuntimeHash
        ) {
            revert UnauthorizedProtocolRootFactory();
        }
        if (_campaignKey == bytes32(0) || _campaignKey != _protocolRootCampaignKey) {
            revert ProtocolRootCampaignMismatch();
        }
        if (_protocolRootActivationState != PROTOCOL_ROOT_INACTIVE) {
            revert ProtocolRootAlreadyActive();
        }

        _protocolRootActivationState = PROTOCOL_ROOT_ACTIVE;
        return PROTOCOL_ROOT_ACTIVATED_MAGIC;
    }

    /// @dev Restricts every derived functional or mutating surface until root activation.
    modifier onlyActiveProtocolRoot() {
        if (_protocolRootActivationState != PROTOCOL_ROOT_ACTIVE) revert ProtocolRootInactive();
        _;
    }

    /// @dev Returns the CREATE address for a proxy whose first CREATE uses nonce one.
    function _createNonceOneAddress(address _proxy) private pure returns (address component_) {
        component_ =
            address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", _proxy, hex"01")))));
    }

    /// @dev Returns EXTCODEHASH without allowing an empty account to masquerade as a component.
    function _runtimeHash(address _target) private view returns (bytes32 hash_) {
        assembly ("memory-safe") {
            hash_ := extcodehash(_target)
        }
    }

    error InvalidProtocolRootActivationConfig();
    error InvalidProtocolRootDeployment();
    error ProtocolRootAlreadyActive();
    error ProtocolRootCampaignMismatch();
    error ProtocolRootFactoryCodeChanged();
    error ProtocolRootInactive();
    error UnauthorizedProtocolRootFactory();
}
