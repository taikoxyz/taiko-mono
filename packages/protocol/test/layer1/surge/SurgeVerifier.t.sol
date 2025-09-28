// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../shared/CommonTest.sol";
import "src/layer1/surge/verifiers/SurgeVerifier.sol";
import "src/layer1/surge/verifiers/LibProofType.sol";
import "test/layer1/based/helpers/ProofTypeFixtures.sol";

contract MockInternalVerifier is IVerifier {
    uint256 internal immutable provingFlag;

    constructor(uint256 _provingFlag) {
        provingFlag = _provingFlag;
    }

    function verifyProof(IVerifier.Context[] calldata, bytes calldata _proof) external view {
        // The proof is used as the source of the flag's value
        uint256 flag = abi.decode(_proof, (uint256));
        require(flag == provingFlag, "MockInternalVerifier: Invalid flag");
    }
}

contract MockTaikoInbox { }

contract SurgeVerifierTestBase is CommonTest {
    address internal taikoInbox;
    SurgeVerifier internal surgeVerifier;

    MockInternalVerifier internal sgxRethVerifier;
    MockInternalVerifier internal sgxGethVerifier;
    MockInternalVerifier internal risc0RethVerifier;
    MockInternalVerifier internal sp1RethVerifier;

    function setUpOnEthereum() internal override {
        taikoInbox = address(new MockTaikoInbox());
        sgxRethVerifier = new MockInternalVerifier(0);
        sgxGethVerifier = new MockInternalVerifier(1);
        sp1RethVerifier = new MockInternalVerifier(2);
        risc0RethVerifier = new MockInternalVerifier(3);

        address surgeVerifierAddr = deploy({
            name: "surge_verifier",
            impl: address(new SurgeVerifier(address(taikoInbox))),
            data: abi.encodeCall(
                SurgeVerifier.init,
                (
                    Alice,
                    address(sgxRethVerifier),
                    address(risc0RethVerifier),
                    address(sp1RethVerifier),
                    address(sgxGethVerifier)
                )
            )
        });
        surgeVerifier = SurgeVerifier(surgeVerifierAddr);
    }
}

contract SurgeVerifierTest is SurgeVerifierTestBase, ProofTypeFixtures {
    using LibProofType for LibProofType.ProofType;

    // Verify proof tests
    // --------------------------------------------------------------------------------------------

    function test_verifyProof_returns_correct_composed_proof_type(uint256 _numProofs)
        external
        transactBy(taikoInbox)
    {
        _numProofs = bound(_numProofs, 0, allProofTypes.length - 1);

        IVerifier.Context[] memory contexts = _createDummyContextArray();

        // Build sub proofs with correct proving flags,
        // and expected composed proof type from fuzzed input
        ISurgeVerifier.SubProof[] memory subProofs = new ISurgeVerifier.SubProof[](_numProofs + 1);
        LibProofType.ProofType expectedComposedProofType;
        for (uint256 i; i <= _numProofs; ++i) {
            subProofs[i] =
                ISurgeVerifier.SubProof({ proofType: allProofTypes[i], proof: abi.encode(i) });
            expectedComposedProofType = expectedComposedProofType.combine(subProofs[i].proofType);
        }

        // Verify the proof
        LibProofType.ProofType composedProofType =
            surgeVerifier.verifyProof(contexts, abi.encode(subProofs));

        // Assert that the correct proof type is composed
        assertTrue(composedProofType.equals(expectedComposedProofType));
    }

    function test_verifyProof_reverts_if_invalid_proof_is_provided(
        uint256 _numProofs,
        uint256[4] memory _provingFlags
    )
        external
        transactBy(taikoInbox)
    {
        _numProofs = bound(_numProofs, 0, allProofTypes.length - 1);

        IVerifier.Context[] memory contexts = _createDummyContextArray();

        // Build sub proofs with incorrect proving flags
        ISurgeVerifier.SubProof[] memory subProofs = new ISurgeVerifier.SubProof[](_numProofs + 1);
        for (uint256 i; i <= _numProofs; ++i) {
            _provingFlags[i] = bound(_provingFlags[i], 0, allProofTypes.length - 1);
            vm.assume(_provingFlags[i] != i); // Force incorrect proving flag

            subProofs[i] = ISurgeVerifier.SubProof({
                proofType: allProofTypes[i],
                proof: abi.encode(_provingFlags[i])
            });
        }

        // Transaction should revert within internal verifier
        vm.expectRevert("MockInternalVerifier: Invalid flag");
        surgeVerifier.verifyProof(contexts, abi.encode(subProofs));
    }

    function test_verifyProof_reverts_if_invalid_proof_type_is_provided(uint256 _index)
        external
        transactBy(taikoInbox)
    {
        _index = bound(_index, 0, zkTeeProofTypes.length - 1);

        IVerifier.Context[] memory contexts = _createDummyContextArray();

        // Build a sub proof with incorrect proof type
        ISurgeVerifier.SubProof[] memory subProofs = new ISurgeVerifier.SubProof[](1);
        // ZK tee is a combination proof type which is not valid for the subproof input
        subProofs[0] =
            ISurgeVerifier.SubProof({ proofType: zkTeeProofTypes[_index], proof: abi.encode(0) });

        // Verify the proof
        vm.expectRevert(abi.encodeWithSelector(ISurgeVerifier.INVALID_PROOF_TYPE.selector));
        surgeVerifier.verifyProof(contexts, abi.encode(subProofs));
    }

    // Upgrade verifier tests
    // --------------------------------------------------------------------------------------------

    function test_markUpgradeable_marks_multiple_verifiers_upgradeable(uint256[4] memory _indices)
        external
        transactBy(taikoInbox)
    {
        // Build composed proof type to upgrade
        LibProofType.ProofType composedProofType;
        for (uint256 i; i < _indices.length; ++i) {
            _indices[i] = bound(_indices[i], 0, allProofTypes.length - 1);
            composedProofType = composedProofType.combine(allProofTypes[_indices[i]]);
        }

        // Mark the verifiers upgradeable
        surgeVerifier.markUpgradeable(composedProofType);

        _assertVerifiersUpgradeable(_indices);
    }

    function test_upgradeVerifier_upgrades_a_verifier(
        uint256 _index,
        address _newVerifier
    )
        external
        transactBy(taikoInbox)
    {
        _index = bound(_index, 0, allProofTypes.length - 1);

        // Mark a verifier as upgradeable
        surgeVerifier.markUpgradeable(allProofTypes[_index]);

        // Alice (the owner) upgrades the verifier
        vm.startPrank(Alice);
        surgeVerifier.upgradeVerifier(allProofTypes[_index], _newVerifier);
        vm.stopPrank();

        // Assert that the verifier is upgraded
        _assertVerifierUpgraded(_index, _newVerifier);
    }

    function test_upgradeVerifier_reverts_if_verifier_is_not_upgradeable(
        uint256 _indexToMark,
        uint256 _indexToUpgrade,
        address _newVerifier
    )
        external
        transactBy(taikoInbox)
    {
        _indexToMark = bound(_indexToMark, 0, allProofTypes.length - 1);
        _indexToUpgrade = bound(_indexToUpgrade, 0, allProofTypes.length - 1);

        vm.assume(_indexToMark != _indexToUpgrade);

        // Mark a verifier as upgradeable
        surgeVerifier.markUpgradeable(allProofTypes[_indexToMark]);

        // Upgrade by Alice (the owner) fails since the verifier is not mark upgradeable
        vm.expectRevert(
            abi.encodeWithSelector(ISurgeVerifier.VERIFIER_NOT_MARKED_UPGRADEABLE.selector)
        );
        vm.startPrank(Alice);
        surgeVerifier.upgradeVerifier(allProofTypes[_indexToUpgrade], _newVerifier);
        vm.stopPrank();
    }

    function test_upgradeVerifier_reverts_if_invalid_proof_type_is_provided(
        uint256 _index,
        address _newVerifier
    )
        external
        transactBy(Alice)
    {
        _index = bound(_index, 0, zkTeeProofTypes.length - 1);

        // Upgrade by Alice (the owner) fails since a composed zk-tee proof type is invalid
        vm.expectRevert(abi.encodeWithSelector(ISurgeVerifier.INVALID_PROOF_TYPE.selector));
        surgeVerifier.upgradeVerifier(zkTeeProofTypes[_index], _newVerifier);
    }

    // Helper functions
    // --------------------------------------------------------------------------------------------

    function _createDummyContextArray() internal pure returns (IVerifier.Context[] memory) {
        IVerifier.Context[] memory contexts = new IVerifier.Context[](1);
        contexts[0] = IVerifier.Context({
            batchId: uint64(0),
            metaHash: bytes32(0),
            transition: ITaikoInbox.Transition({
                parentHash: bytes32(0),
                blockHash: bytes32(0),
                stateRoot: bytes32(0)
            })
        });
        return contexts;
    }

    function _assertVerifiersUpgradeable(uint256[4] memory _indices) internal view {
        bool upgradeable;
        for (uint256 i; i < _indices.length; ++i) {
            if (_indices[i] == 0) {
                (upgradeable,) = surgeVerifier.sgxRethVerifier();
                assertTrue(upgradeable);
            } else if (_indices[i] == 1) {
                (upgradeable,) = surgeVerifier.sgxGethVerifier();
                assertTrue(upgradeable);
            } else if (_indices[i] == 2) {
                (upgradeable,) = surgeVerifier.sp1RethVerifier();
                assertTrue(upgradeable);
            } else if (_indices[i] == 3) {
                (upgradeable,) = surgeVerifier.risc0RethVerifier();
                assertTrue(upgradeable);
            }
        }
    }

    function _assertVerifierUpgraded(uint256 _index, address _newVerifier) internal view {
        bool upgradeable;
        address expectedVerifier;

        if (_index == 0) {
            (upgradeable, expectedVerifier) = surgeVerifier.sgxRethVerifier();
        } else if (_index == 1) {
            (upgradeable, expectedVerifier) = surgeVerifier.sgxGethVerifier();
        } else if (_index == 2) {
            (upgradeable, expectedVerifier) = surgeVerifier.sp1RethVerifier();
        } else if (_index == 3) {
            (upgradeable, expectedVerifier) = surgeVerifier.risc0RethVerifier();
        }

        assertFalse(upgradeable);
        assertEq(expectedVerifier, _newVerifier);

        // Check that other verifiers are untouched
        if (_index != 0) {
            (, expectedVerifier) = surgeVerifier.sgxRethVerifier();
            assertTrue(expectedVerifier != _newVerifier);
        }
        if (_index != 1) {
            (, expectedVerifier) = surgeVerifier.sgxGethVerifier();
            assertTrue(expectedVerifier != _newVerifier);
        }
        if (_index != 2) {
            (, expectedVerifier) = surgeVerifier.sp1RethVerifier();
            assertTrue(expectedVerifier != _newVerifier);
        }
        if (_index != 3) {
            (, expectedVerifier) = surgeVerifier.risc0RethVerifier();
            assertTrue(expectedVerifier != _newVerifier);
        }
    }
}
