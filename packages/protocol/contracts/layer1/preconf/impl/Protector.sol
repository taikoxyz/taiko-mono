// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "src/layer1/preconf/iface/IProtector.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";

/// @title Protector
/// @custom:security-contact security@taiko.xyz
contract Protector is IProtector, EssentialContract {
    address public immutable urc;

    uint128 public signingThreshold;
    uint128 public numSigners;

    mapping(address signerAddress => bool isSigner) public signers;

    constructor(address _urc) {
        urc = _urc;
    }

    function init(uint128 _signingThreshold, address[] memory _signers) external initializer {
        __Essential_init(address(0));
        __Protector_init(_signingThreshold, _signers);
    }

    function slash(
        Delegation calldata, /*_delegation*/
        Commitment calldata, /*_commitment*/
        address _committer,
        bytes calldata _evidence,
        address /*_challenger*/
    )
        external
        nonReentrant
        onlyFrom(urc)
        returns (uint256)
    {
        // `_evidence` is expected to be a list of signatures advocating for the slashing of the
        // committer
        bytes32 digest =
            keccak256(abi.encode(LibPreconfConstants.PROTECTOR_SLASH_DOMAIN_SEPARATOR, _committer));
        _verifySignatures(digest, abi.decode(_evidence, (bytes[])));

        // TODO: Make this confiugurable
        return 1 ether;
    }

    // Signers management functions
    // -----------------------------------------------------------------------------------

    /// @inheritdoc IProtector
    function addSigner(address _signer, bytes[] memory _signatures) external {
        require(!signers[_signer], SignerAlreadyExists());

        bytes32 digest = keccak256(
            abi.encode(LibPreconfConstants.ADD_PROTECTOR_SIGNER_DOMAIN_SEPARATOR, _signer)
        );
        _verifySignatures(digest, _signatures);

        signers[_signer] = true;
        unchecked {
            ++numSigners;
        }

        emit SignerAdded(_signer);
    }

    /// @inheritdoc IProtector
    function removeSigner(address _signer, bytes[] memory _signatures) external {
        require(signers[_signer], SignerDoesNotExist());
        require(numSigners > signingThreshold, CannotRemoveSignerWhenThresholdIsReached());

        bytes32 digest = keccak256(
            abi.encode(LibPreconfConstants.REMOVE_PROTECTOR_SIGNER_DOMAIN_SEPARATOR, _signer)
        );
        _verifySignatures(digest, _signatures);

        delete signers[_signer];
        unchecked {
            --numSigners;
        }

        emit SignerRemoved(_signer);
    }

    /// @inheritdoc IProtector
    function updateSigningThreshold(
        uint128 _signingThreshold,
        bytes[] memory _signatures
    )
        external
    {
        require(_signingThreshold <= numSigners, InvalidSigningThreshold());

        bytes32 digest = keccak256(
            abi.encode(
                LibPreconfConstants.UPDATE_PROTECTOR_SIGNING_THRESHOLD_DOMAIN_SEPARATOR,
                _signingThreshold
            )
        );
        _verifySignatures(digest, _signatures);

        signingThreshold = _signingThreshold;

        emit SigningThresholdUpdated(_signingThreshold);
    }

    // Internal functions
    // -----------------------------------------------------------------------------------

    function __Protector_init(uint128 _signingThreshold, address[] memory _signers) internal {
        require(_signingThreshold <= _signers.length, InvalidSigningThreshold());

        for (uint256 i; i < _signers.length; ++i) {
            signers[_signers[i]] = true;
        }

        numSigners = uint128(_signers.length);
        signingThreshold = _signingThreshold;
    }

    function _verifySignatures(bytes32 digest, bytes[] memory _signatures) internal view {
        address lastSigner;
        address currentSigner;

        for (uint256 i; i < _signatures.length; ++i) {
            // Recover the signer from the signature
            currentSigner = ECDSA.recover(digest, _signatures[i]);
            require(signers[currentSigner], NotAnExistingSigner());

            // To prevent replay of signatures
            require(lastSigner < currentSigner, SignersMustBeSortedInAscendingOrder());

            lastSigner = currentSigner;
        }
    }
}
