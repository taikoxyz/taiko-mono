// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibNames.sol";
import "../../verifiers/IVerifier.sol";

/// @title OpVerifier
/// @notice This contract is the implementation of verifying optimism signature proofs
/// onchain.
/// @custom:security-contact security@taiko.xyz
contract OpVerifier is EssentialContract, IVerifier {
    address public immutable taikoInbox;
    address public immutable proofVerifier;

    uint256[50] private __gap;

    constructor(address _taikoInbox, address _proofVerifier) {
        taikoInbox = _taikoInbox;
        proofVerifier = _proofVerifier;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context[] calldata _ctxs,
        bytes calldata _proof
    )
        external
        onlyFromEither(taikoInbox, proofVerifier)
    { }
}
