// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IEthMinter} from "src/shared/bridge/IEthMinter.sol";
import {EssentialContract } from "src/shared/common/EssentialContract.sol";
import {IShadow} from "../iface/IShadow.sol";
import {IShadowVerifier} from "../iface/IShadowVerifier.sol";
import {ShadowPublicInputs} from "../lib/ShadowPublicInputs.sol";


import "./Shadow_Layout.sol"; // DO NOT DELETE


/// @custom:security-contact security@taiko.xyz
contract Shadow is IShadow, EssentialContract {
    IShadowVerifier public immutable verifier;
    IEthMinter public immutable ethMinter;

    mapping(bytes32 _nullifier => bool _consumed) private _consumed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _verifier, address _ethMinter) {
        require(_verifier != address(0), ZERO_ADDRESS());
        require(_ethMinter != address(0), ZERO_ADDRESS());
        verifier = IShadowVerifier(_verifier);
        ethMinter = IEthMinter(_ethMinter);
    }

    /// @notice Initializes the contract.
    function initialize(address _owner) external initializer {
        __Essential_init(_owner);
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

        ethMinter.mintEth(_input.recipient, _input.amount);

        emit Claimed(_input.nullifier, _input.recipient, _input.amount);
    }
}
