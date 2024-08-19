// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../IVerifier.sol";

/// @title ComposeVerifier
/// @notice This contract is an abstract verifier that composes multiple sub-verifiers to validate
/// proofs.
/// It ensures that a set of sub-proofs are verified by their respective verifiers before
/// considering the overall proof as valid.
/// @custom:security-contact security@taiko.xyz
abstract contract ComposeVerifier is IVerifier {
    enum Mode {
        ALL,
        ONE,
        MAJORITY
    }

    struct SubProof {
        address verifier;
        bytes proof;
    }

    error INSUFFICIENT_PROOF();

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
        address[] memory verifiers = getSubVerifiers();

        for (uint256 i; i < verifiers.length; ++i) {
            // Store the value 1 in the temporary storage slot using inline assembly
            uint256 slot = uint256(uint160(verifiers[i]));
            assembly {
                sstore(slot, 1)
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

            try IVerifier(subproofs[i].verifier).verifyProof(
                _ctx, _tran, TaikoData.TierProof(_proof.tier, subproofs[i].proof)
            ) {
                unchecked {
                    numSuccesses += 1;
                }
            } catch { }
        }

        if (numSuccesses < _getThreshold(verifiers.length)) {
            revert INSUFFICIENT_PROOF();
        }
    }

    /// @notice Returns the list of sub-verifiers.
    /// @return An array of addresses of sub-verifiers.
    function getSubVerifiers() public view virtual returns (address[] memory);

    /// @notice Returns the mode of the verifier.
    /// @return The mode of the verifier.
    function getMode() public pure virtual returns (Mode);

    /// @notice Calculates the threshold based on the number of sub-verifiers and the mode.
    /// @param _numSubVerifiers The number of sub-verifiers.
    /// @return The threshold number of successful verifications required.
    function _getThreshold(uint256 _numSubVerifiers) private pure returns (uint256) {
        Mode mode = getMode();
        if (mode == Mode.ALL) return _numSubVerifiers;
        else if (mode == Mode.ONE) return 1;
        else return _numSubVerifiers / 2 + 1;
    }
}
