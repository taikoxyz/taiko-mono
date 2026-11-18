// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { ComposeVerifier } from "src/layer1/verifiers/compose/ComposeVerifier.sol";
import { ZkRequiredVerifier } from "src/layer1/verifiers/compose/ZkRequiredVerifier.sol";

/// @dev Only remote cryptography is stubbed. The real adapters enforce current image/program
/// trust, and the real composition enforces every accepted two-proof combination.
contract MockZkCryptographicVerifier {
    fallback() external { }
}

contract EtnaRecoverySettlementFreezeTest is EtnaLandTestBase {
    bytes32 private constant _R0_BLOCK = keccak256("Etna RISC0 block image");
    bytes32 private constant _R0_AGGREGATION = keccak256("Etna RISC0 aggregation image");
    bytes32 private constant _SP1_BLOCK = keccak256("Etna SP1 block program");
    bytes32 private constant _SP1_AGGREGATION = keccak256("Etna SP1 aggregation program");

    Risc0Verifier private _risc0;
    SP1Verifier private _sp1;
    ZkRequiredVerifier private _composite;

    function setUp() public override {
        super.setUp();
        address remote = address(new MockZkCryptographicVerifier());
        _risc0 = new Risc0Verifier(L2_CHAIN_ID, remote, address(this));
        _sp1 = new SP1Verifier(L2_CHAIN_ID, remote, address(this));
        _composite = new ZkRequiredVerifier(
            address(0), address(landVerifier), address(_risc0), address(_sp1)
        );
        _risc0.setImageIdTrusted(_R0_BLOCK, true);
        _risc0.setImageIdTrusted(_R0_AGGREGATION, true);
        _sp1.setProgramTrusted(_SP1_BLOCK, true);
        _sp1.setProgramTrusted(_SP1_AGGREGATION, true);
        IEtnaInbox.Config memory config = _defaultConfig();
        config.proofVerifier = address(_composite);
        _inbox().upgradeTo(address(_newInboxImpl(config)));
    }

    function test_recover_TwoStageZkTrustRevocationKeepsAuthorizedCheckpointStable() external {
        // Ordinary pause still permits settlement, which invalidates an earlier authorization.
        _inbox().pause();
        vm.blobhashes(blobHashes);
        _inbox().land(_input(0, 6), _leaves(0, 6), _proof(1));
        vm.expectRevert(IEtnaInbox.CheckpointMismatch.selector);
        _recover(0, 0, 0);

        // All three proofs are prepared before revocation and initially accepted by the policy.
        IEtnaInbox.LandInput memory input = _input(6, 12);
        bytes32[] memory leaves = _leaves(6, 12);
        bytes32 statement = _statement(input, _inbox().landings(6), _cutHash(input, leaves));
        bytes[3] memory prepared = [_proof(0), _proof(1), _proof(2)];
        for (uint256 i; i < prepared.length; ++i) {
            _composite.verifyProof(0, statement, prepared[i]);
        }

        // Revoking only one ZK lane leaves SGX + SP1 available.
        _risc0.setImageIdTrusted(_R0_AGGREGATION, false);
        vm.expectRevert(Risc0Verifier.RISC_ZERO_INVALID_AGGREGATION_IMAGE_ID.selector);
        _composite.verifyProof(0, statement, prepared[0]);
        _composite.verifyProof(0, statement, prepared[1]);

        // First governance stage: revoke trust on both dedicated ZK lanes. Every prepared proof
        // now fails at proof time, even though SGX stays available and the Inbox pause is inert.
        _risc0.setImageIdTrusted(_R0_BLOCK, false);
        _sp1.setProgramTrusted(_SP1_AGGREGATION, false);
        _sp1.setProgramTrusted(_SP1_BLOCK, false);
        for (uint256 i; i < prepared.length; ++i) {
            bytes4 expected = i == 1
                ? SP1Verifier.SP1_INVALID_AGGREGATION_VKEY.selector
                : Risc0Verifier.RISC_ZERO_INVALID_AGGREGATION_IMAGE_ID.selector;
            vm.expectRevert(expected);
            _inbox().land(input, leaves, prepared[i]);
            assertEq(_inbox().lastCheckpoint().height, 6);
            assertEq(_inbox().recoveryGeneration(), 0);
        }

        // Only after the revocation stage is finalized does the DAO read and authorize this
        // tuple. The test advances L1 to represent the separate authorization/execution stage.
        uint256 expectedC = _inbox().lastCheckpoint().height;
        uint48 expectedGeneration = _inbox().recoveryGeneration();
        uint256 expectedNonce = _inbox().recoveryNonce();
        vm.roll(block.number + 100);
        _recover(expectedGeneration, expectedC, expectedNonce);
        assertEq(_inbox().lastCheckpoint().height, 6);
        assertEq(_inbox().recoveryGeneration(), 1);
        assertEq(_inbox().recoveryNonce(), 1);

        // Restore only the chosen SP1 lane after recovery. The new generation can land while
        // RISC0 remains disabled; no stale expected checkpoint or nonce is tolerated.
        _sp1.setProgramTrusted(_SP1_BLOCK, true);
        _sp1.setProgramTrusted(_SP1_AGGREGATION, true);
        _setReference(block.number - 1, bytes32(uint256(1234)));
        input = _input(6, 12);
        _inbox().land(input, leaves, _proof(1));
        assertEq(_inbox().lastCheckpoint().height, 12);
        assertFalse(_risc0.isImageTrusted(_R0_BLOCK));
    }

    /// @dev Builds SGX+RISC0, SGX+SP1 or RISC0+SP1 proof bytes using the real adapter formats.
    function _proof(uint256 _pair) private pure returns (bytes memory) {
        ComposeVerifier.SubProof[] memory sub = new ComposeVerifier.SubProof[](2);
        sub[0] = _pair == 2
            ? ComposeVerifier.SubProof(ComposeVerifier.VerifierType.RISC0_RETH, _risc0Proof())
            : ComposeVerifier.SubProof(ComposeVerifier.VerifierType.SGX_RETH, PROOF);
        sub[1] = _pair == 0
            ? ComposeVerifier.SubProof(ComposeVerifier.VerifierType.RISC0_RETH, _risc0Proof())
            : ComposeVerifier.SubProof(
                ComposeVerifier.VerifierType.SP1_RETH,
                abi.encodePacked(_SP1_AGGREGATION, _SP1_BLOCK, hex"abcd")
            );
        return abi.encode(sub);
    }

    function _risc0Proof() private pure returns (bytes memory) {
        return abi.encode(bytes("seal"), _R0_BLOCK, _R0_AGGREGATION);
    }

    function _recover(uint48 _generation, uint256 _checkpoint, uint256 _nonce) private {
        _inbox()
            .recover(
                _generation,
                _checkpoint,
                _nonce,
                block.timestamp,
                new IEtnaInbox.Exclusion[](0),
                new uint256[](0),
                0
            );
    }
}
