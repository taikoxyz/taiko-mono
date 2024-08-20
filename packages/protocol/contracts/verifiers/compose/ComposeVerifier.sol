// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/EssentialContract.sol";
import "../IVerifier.sol";

/// @title ComposeVerifier
/// @notice This contract is an abstract verifier that composes multiple sub-verifiers to validate
/// proofs.
/// It ensures that a set of sub-proofs are verified by their respective verifiers before
/// considering the overall proof as valid.
/// @custom:security-contact security@taiko.xyz
abstract contract ComposeVerifier is EssentialContract, IVerifier {
    struct SubProof {
        address verifier;
        bytes proof;
    }

    error INSUFFICIENT_PROOF();

    event SubProofError(address indexed verifier, bytes returnData);

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @notice Verifies one or more sub-proofs.
    /// @param _ctx The context of the proof verification.
    /// @param _tran The transition to verify.
    /// @param _proof The proof to verify.
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
    {
        (address[] memory verifiers, uint256 threshold) = getSubVerifiersAndThreshold();

        for (uint256 i; i < verifiers.length; ++i) {
            // Store the value 1 in the temporary storage slot using inline assembly
            uint256 slot = uint256(uint160(verifiers[i]));
            assembly {
                tstore(slot, 1)
            }
        }

        SubProof[] memory subproofs = abi.decode(_proof.data, (SubProof[]));
        uint256 numSuccesses;

        for (uint256 i; i < subproofs.length; ++i) {
            uint256 slot = uint256(uint160(subproofs[i].verifier));

            assembly {
                switch tload(slot)
                case 1 { tstore(slot, 0) }
                default {
                    let message := "INVALID_VERIFIER"
                    mstore(0x0, message)
                    revert(0x0, 0x20)
                }
            }

            (bool success, bytes memory returnData) = subproofs[i].verifier.call(
                abi.encodeCall(
                    IVerifier.verifyProof,
                    (_ctx, _tran, TaikoData.TierProof(_proof.tier, subproofs[i].proof))
                )
            );
            if (success) {
                unchecked {
                    numSuccesses += 1;
                }
            } else {
                emit SubProofError(subproofs[i].verifier, returnData);
            }
        }

        if (numSuccesses < threshold) {
            revert INSUFFICIENT_PROOF();
        }
    }

    /// @notice Returns the list of sub-verifiers and calculates the threshold.
    /// @return verifiers_ An array of addresses of sub-verifiers.
    /// @return threshold_ The threshold number of successful verifications required.
    function getSubVerifiersAndThreshold()
        public
        view
        virtual
        returns (address[] memory verifiers_, uint256 threshold_);
}
