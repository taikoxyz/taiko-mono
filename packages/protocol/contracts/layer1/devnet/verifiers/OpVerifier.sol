// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibStrings.sol";
import "../../verifiers/IVerifier.sol";

/// @title OpVerifier
/// @notice This contract is the implementation of verifying optimism signature proofs
/// onchain.
/// @custom:security-contact security@taiko.xyz
contract OpVerifier is EssentialContract, IVerifier {
    uint64 public immutable taikoChainId;

    uint256[50] private __gap;

    constructor(uint64 _taikoChainId) {
        taikoChainId = _taikoChainId;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupResolver The {IResolver} used by this rollup.
    function init(address _owner, address _rollupResolver) external initializer {
        __Essential_init(_owner, _rollupResolver);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context[] calldata _ctxs,
        bytes calldata _proof
    )
        external
        onlyFromNamedEither(LibStrings.B_TAIKO, LibStrings.B_PROOF_VERIFIER)
    { }
}
