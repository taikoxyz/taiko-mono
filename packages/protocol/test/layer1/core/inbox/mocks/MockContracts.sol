// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";

/// @title MockProofVerifier
/// @notice Mock proof verifier that always accepts proofs
contract MockProofVerifier is IProofVerifier {
    bool public shouldRevert;

    function setRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function verifyProof(uint256, bytes32, bytes calldata) external view {
        if (shouldRevert) {
            revert("MockProofVerifier: invalid proof");
        }
    }
}

/// @title MockProposerChecker
/// @notice Mock proposer checker for testing
contract MockProposerChecker is IProposerChecker {
    bool public shouldRevert;
    uint40 public submissionWindowEnd;
    mapping(address => bool) public allowedProposers;

    function setRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setSubmissionWindowEnd(uint40 _end) external {
        submissionWindowEnd = _end;
    }

    function allowProposer(address _proposer) external {
        allowedProposers[_proposer] = true;
    }

    function disallowProposer(address _proposer) external {
        allowedProposers[_proposer] = false;
    }

    function checkProposer(
        address _proposer,
        bytes calldata
    )
        external
        view
        returns (uint40 endOfSubmissionWindowTimestamp_)
    {
        if (shouldRevert) {
            revert InvalidProposer();
        }
        if (!allowedProposers[_proposer]) {
            revert InvalidProposer();
        }
        return submissionWindowEnd;
    }
}
