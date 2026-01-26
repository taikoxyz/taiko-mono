// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IEtherMinter} from "../iface/IEtherMinter.sol";
import {IShadow} from "../iface/IShadow.sol";
import {IShadowVerifier} from "../iface/IShadowVerifier.sol";
import {OwnableUpgradeable} from "../lib/OwnableUpgradeable.sol";
import {ShadowPublicInputs} from "../lib/ShadowPublicInputs.sol";

/// @custom:security-contact security@taiko.xyz

contract Shadow is IShadow, OwnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IShadowVerifier public immutable verifier;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IEtherMinter public immutable etherMinter;

    mapping(bytes32 _nullifier => bool _consumed) private _consumed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _verifier, address _etherMinter) {
        require(_verifier != address(0), ZeroAddress());
        require(_etherMinter != address(0), ZeroAddress());
        verifier = IShadowVerifier(_verifier);
        etherMinter = IEtherMinter(_etherMinter);
    }

    /// @notice Initializes the contract.
    function initialize(address _owner) external initializer {
        __OwnableUpgradeable_init(_owner);
    }

    /// @notice Returns whether the nullifier has been consumed.
    function isConsumed(bytes32 _nullifier) external view returns (bool _isConsumed_) {
        _isConsumed_ = _consumed[_nullifier];
    }

    /// @notice Submits a proof and public inputs to mint ETH.
    function claim(bytes calldata _proof, PublicInput calldata _input) external {
        require(_input.chainId == block.chainid, ChainIdMismatch(_input.chainId, block.chainid));
        require(_input.amount > 0, InvalidAmount(_input.amount));
        require(_input.recipient != address(0), InvalidRecipient(_input.recipient));
        require(ShadowPublicInputs.powDigestIsValid(_input.powDigest), InvalidPowDigest(_input.powDigest));

        require(verifier.verifyProof(_proof, _input), ProofVerificationFailed());

        require(!_consumed[_input.nullifier], NullifierAlreadyConsumed(_input.nullifier));
        _consumed[_input.nullifier] = true;

        etherMinter.mintEther(_input.recipient, _input.amount);

        emit Claimed(_input.nullifier, _input.recipient, _input.amount);
    }
}
