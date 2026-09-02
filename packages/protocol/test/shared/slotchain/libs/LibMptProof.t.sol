// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibCanonicalRLP } from "../../../../contracts/shared/slotchain/libs/LibCanonicalRLP.sol";
import { LibMptProof } from "../../../../contracts/shared/slotchain/libs/LibMptProof.sol";
import { CanonicalTrieFixtures } from "../utils/CanonicalTrieFixtures.sol";
import { Test } from "forge-std/src/Test.sol";

contract MptProofHarness {
    function verifyAccount(
        bytes calldata _framedPath,
        uint256 _nodeCount,
        bytes32 _stateRoot,
        address _account,
        bytes32 _codeHash
    )
        external
        pure
        returns (bytes32 storageRoot_)
    {
        (LibMptProof.Path memory path, uint256 end) =
            LibMptProof.parsePath(_framedPath, 0, _framedPath.length, _nodeCount);
        if (end != _framedPath.length) revert UnexpectedFixtureSuffix();
        return LibMptProof.verifyAccount(_framedPath, path, _stateRoot, _account, _codeHash);
    }

    function verifyStorage(
        bytes calldata _framedPath,
        uint256 _nodeCount,
        bytes32 _storageRoot,
        bytes32 _storageKey
    )
        external
        pure
        returns (bytes32 value_)
    {
        (LibMptProof.Path memory path, uint256 end) =
            LibMptProof.parsePath(_framedPath, 0, _framedPath.length, _nodeCount);
        if (end != _framedPath.length) revert UnexpectedFixtureSuffix();
        return LibMptProof.verifyStorageValue(_framedPath, path, _storageRoot, _storageKey);
    }

    function parsePath(
        bytes calldata _framedPath,
        uint256 _nodeCount
    )
        external
        pure
        returns (uint256 end_)
    {
        (, end_) = LibMptProof.parsePath(_framedPath, 0, _framedPath.length, _nodeCount);
    }

    error UnexpectedFixtureSuffix();
}

contract LibMptProofTest is Test {
    MptProofHarness private harness;

    function setUp() external {
        harness = new MptProofHarness();
    }

    function test_singleLeafAccountAndStorageProofs_UseActualEthereumValueLayers() external view {
        CanonicalTrieFixtures.RegistrationFixture memory fixture =
            CanonicalTrieFixtures.registrationFixture();
        bytes memory accountPath = _slice(fixture.proof, 4, _frameEnd(fixture.proof, 4));
        uint256 storageOffset = 4 + accountPath.length;
        bytes memory storagePath = _slice(fixture.proof, storageOffset, fixture.proof.length);

        assertEq(
            harness.verifyAccount(
                accountPath, 1, fixture.stateRoot, fixture.account, fixture.codeHash
            ),
            fixture.storageRoot
        );
        assertEq(
            harness.verifyStorage(storagePath, 1, fixture.storageRoot, fixture.storageKey),
            fixture.expectedValue
        );
    }

    function test_inlineAndHashedChildBoundary_Accepts31And32ByteNodes() external view {
        bytes32 key = keccak256("inline-hash-boundary-key");
        bytes32 inlineValue = bytes32(uint256(1) << 191);
        (bytes memory inlinePath, bytes32 inlineRoot, uint256 inlineLength) =
            CanonicalTrieFixtures.extensionStorageProof(key, inlineValue, true);
        assertEq(inlineLength, 31);
        assertEq(harness.verifyStorage(inlinePath, 2, inlineRoot, key), inlineValue);

        bytes32 hashedValue = bytes32(uint256(1) << 199);
        (bytes memory hashedPath, bytes32 hashedRoot, uint256 hashedLength) =
            CanonicalTrieFixtures.extensionStorageProof(key, hashedValue, false);
        assertEq(hashedLength, 32);
        assertEq(harness.verifyStorage(hashedPath, 2, hashedRoot, key), hashedValue);
    }

    function test_inlineAndHashedChildBoundary_RejectsTheTwoAlternativeEdges() external {
        bytes32 key = keccak256("noncanonical-child-edge");
        bytes32 shortValue = bytes32(uint256(1) << 191);
        (bytes memory hashedShortPath, bytes32 hashedShortRoot, uint256 shortLength) =
            CanonicalTrieFixtures.extensionStorageProof(key, shortValue, false);
        assertEq(shortLength, 31);
        vm.expectRevert(LibMptProof.MptReferenceMismatch.selector);
        harness.verifyStorage(hashedShortPath, 2, hashedShortRoot, key);

        bytes32 longValue = bytes32(uint256(1) << 199);
        (bytes memory inlineLongPath, bytes32 inlineLongRoot, uint256 longLength) =
            CanonicalTrieFixtures.extensionStorageProof(key, longValue, true);
        assertEq(longLength, 32);
        vm.expectRevert(LibMptProof.InvalidMptChildReference.selector);
        harness.verifyStorage(inlineLongPath, 2, inlineLongRoot, key);
    }

    function test_selectedInlineChild_StillReceivesFullSemanticValidation() external {
        bytes32 key = keccak256("malformed-selected-inline-child");
        bytes memory malformedSelected = hex"c0";
        bytes[] memory extensionItems = new bytes[](2);
        extensionItems[0] =
            CanonicalTrieFixtures.rlpBytes(CanonicalTrieFixtures.hexPrefix(key, 0, 60, false));
        extensionItems[1] = malformedSelected;
        bytes memory extension = CanonicalTrieFixtures.rlpList(extensionItems);
        bytes memory path = bytes.concat(
            CanonicalTrieFixtures.framedNode(extension),
            CanonicalTrieFixtures.framedNode(malformedSelected)
        );

        vm.expectRevert(LibCanonicalRLP.RlpOutOfBounds.selector);
        harness.verifyStorage(path, 2, keccak256(extension), key);
    }

    function test_nonSelectedInlinePayload_IsOpaqueToMembership() external view {
        bytes32 key = keccak256("opaque-nonselected-inline-child");
        bytes32 value = bytes32(uint256(0x80));
        (bytes memory pathA, bytes32 rootA) = _branchPathWithOpaqueSibling(key, value, hex"c181");
        (bytes memory pathB, bytes32 rootB) = _branchPathWithOpaqueSibling(key, value, hex"c1b8");

        assertNotEq(rootA, rootB);
        assertEq(harness.verifyStorage(pathA, 2, rootA, key), value);
        assertEq(harness.verifyStorage(pathB, 2, rootB, key), value);
    }

    function test_branchValue_RequiresCanonicalEmptyStringDuringSelectedTraversal() external {
        bytes32 key = keccak256("canonical-empty-branch-value");
        bytes32 value = bytes32(uint256(0x80));
        (bytes memory validPath, bytes32 validRoot) = _branchPath(key, value, hex"c181", hex"80");
        assertEq(harness.verifyStorage(validPath, 2, validRoot, key), value);

        (bytes memory nonemptyPath, bytes32 nonemptyRoot) =
            _branchPath(key, value, hex"c181", hex"01");
        vm.expectRevert(LibMptProof.InvalidMptBranch.selector);
        harness.verifyStorage(nonemptyPath, 2, nonemptyRoot, key);

        (bytes memory listPath, bytes32 listRoot) = _branchPath(key, value, hex"c181", hex"c0");
        vm.expectRevert(LibMptProof.InvalidMptBranch.selector);
        harness.verifyStorage(listPath, 2, listRoot, key);
    }

    function test_pathTraversal_RejectsWrongKeyRootMissingAndSurplusNodes() external {
        bytes32 key = keccak256("path-consumption");
        bytes32 value = bytes32(uint256(1) << 199);
        (bytes memory path, bytes32 root,) =
            CanonicalTrieFixtures.extensionStorageProof(key, value, false);

        vm.expectRevert(LibMptProof.MptKeyMismatch.selector);
        harness.verifyStorage(path, 2, root, bytes32(uint256(key) ^ 1));

        vm.expectRevert(LibMptProof.MptReferenceMismatch.selector);
        harness.verifyStorage(path, 2, bytes32(uint256(root) ^ 1), key);

        bytes memory rootOnly = _slice(path, 0, _frameEnd(path, 0));
        vm.expectRevert(LibMptProof.IncompleteMptPath.selector);
        harness.verifyStorage(rootOnly, 1, root, key);

        bytes memory surplus = bytes.concat(path, _slice(path, 0, _frameEnd(path, 0)));
        vm.expectRevert(LibMptProof.SurplusMptNode.selector);
        harness.verifyStorage(surplus, 3, root, key);

        uint256 firstEnd = _frameEnd(path, 0);
        bytes memory swapped =
            bytes.concat(_slice(path, firstEnd, path.length), _slice(path, 0, firstEnd));
        vm.expectRevert(LibMptProof.MptReferenceMismatch.selector);
        harness.verifyStorage(swapped, 2, root, key);
    }

    function test_branchTraversal_ConsumesAll64NibblesAndRejectsEmptyExtension() external {
        bytes32 key = keccak256("dense-branch-path");
        bytes32 value = bytes32(uint256(0x80));
        (bytes memory densePath, bytes32 root) =
            CanonicalTrieFixtures.densePath(key, CanonicalTrieFixtures.rlpUint(value));
        assertEq(harness.verifyStorage(densePath, 65, root, key), value);

        bytes memory child = CanonicalTrieFixtures.storageLeaf(key, value, 0, 64);
        bytes[] memory extensionItems = new bytes[](2);
        extensionItems[0] = hex"00";
        extensionItems[1] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(keccak256(child)));
        bytes memory emptyExtension = CanonicalTrieFixtures.rlpList(extensionItems);
        bytes memory invalidPath = bytes.concat(
            CanonicalTrieFixtures.framedNode(emptyExtension),
            CanonicalTrieFixtures.framedNode(child)
        );
        vm.expectRevert(LibMptProof.InvalidMptHexPrefix.selector);
        harness.verifyStorage(invalidPath, 2, keccak256(emptyExtension), key);
    }

    function test_accountProof_RejectsIdentityCodeHashAndAccountShapeMutations() external {
        CanonicalTrieFixtures.RegistrationFixture memory fixture =
            CanonicalTrieFixtures.registrationFixture();
        bytes memory accountPath = _slice(fixture.proof, 4, _frameEnd(fixture.proof, 4));

        vm.expectRevert(LibMptProof.MptKeyMismatch.selector);
        harness.verifyAccount(
            accountPath,
            1,
            fixture.stateRoot,
            address(uint160(fixture.account) ^ 1),
            fixture.codeHash
        );

        vm.expectRevert(LibMptProof.InvalidMptAccount.selector);
        harness.verifyAccount(
            accountPath,
            1,
            fixture.stateRoot,
            fixture.account,
            bytes32(uint256(fixture.codeHash) ^ 1)
        );

        vm.expectRevert(LibMptProof.InvalidMptExpectation.selector);
        harness.verifyAccount(accountPath, 1, bytes32(0), fixture.account, fixture.codeHash);
    }

    function test_storageProof_RejectsZeroAndAlternativeInnerRlp() external {
        bytes32 key = keccak256("storage-value-layer");
        bytes memory zeroLeaf = CanonicalTrieFixtures.leaf(key, hex"80", 0, 64);
        bytes memory zeroPath = CanonicalTrieFixtures.framedNode(zeroLeaf);
        vm.expectRevert(LibMptProof.InvalidMptStorageValue.selector);
        harness.verifyStorage(zeroPath, 1, keccak256(zeroLeaf), key);

        bytes memory nonminimalLeaf = CanonicalTrieFixtures.leaf(key, hex"8100", 0, 64);
        bytes memory nonminimalPath = CanonicalTrieFixtures.framedNode(nonminimalLeaf);
        vm.expectRevert();
        harness.verifyStorage(nonminimalPath, 1, keccak256(nonminimalLeaf), key);
    }

    function test_parsePath_EnforcesCountNodeAndContainerBounds() external {
        vm.expectRevert(LibMptProof.InvalidMptPathGeometry.selector);
        harness.parsePath(hex"", 0);

        vm.expectRevert(LibMptProof.InvalidMptPathGeometry.selector);
        harness.parsePath(hex"0001c0", 66);

        vm.expectRevert(LibMptProof.InvalidMptNodeGeometry.selector);
        harness.parsePath(hex"0000", 1);

        bytes memory oversized = bytes.concat(hex"0259", new bytes(601));
        vm.expectRevert(LibMptProof.InvalidMptNodeGeometry.selector);
        harness.parsePath(oversized, 1);

        vm.expectRevert(LibMptProof.InvalidMptNodeGeometry.selector);
        harness.parsePath(hex"0002c0", 1);

        bytes memory exactNodeCap = bytes.concat(hex"0258", new bytes(600));
        assertEq(harness.parsePath(exactNodeCap, 1), exactNodeCap.length);

        bytes memory sixtyFive;
        for (uint256 i; i < 65; ++i) {
            sixtyFive = bytes.concat(sixtyFive, hex"0001c0");
        }
        assertEq(harness.parsePath(sixtyFive, 65), sixtyFive.length);
        vm.expectRevert(LibMptProof.InvalidMptPathGeometry.selector);
        harness.parsePath(sixtyFive, 66);
    }

    function _branchPathWithOpaqueSibling(
        bytes32 _key,
        bytes32 _value,
        bytes memory _opaqueSibling
    )
        private
        pure
        returns (bytes memory path_, bytes32 root_)
    {
        return _branchPath(_key, _value, _opaqueSibling, hex"80");
    }

    function _branchPath(
        bytes32 _key,
        bytes32 _value,
        bytes memory _opaqueSibling,
        bytes memory _branchValue
    )
        private
        pure
        returns (bytes memory path_, bytes32 root_)
    {
        bytes memory leaf = CanonicalTrieFixtures.storageLeaf(_key, _value, 1, 63);
        bytes[] memory items = new bytes[](17);
        for (uint256 i; i < 16; ++i) {
            items[i] = hex"80";
        }
        uint256 selected = CanonicalTrieFixtures.nibble(_key, 0);
        items[selected] = CanonicalTrieFixtures.rlpBytes(abi.encodePacked(keccak256(leaf)));
        items[(selected + 1) % 16] = _opaqueSibling;
        items[16] = _branchValue;
        bytes memory branch = CanonicalTrieFixtures.rlpList(items);
        root_ = keccak256(branch);
        path_ = bytes.concat(
            CanonicalTrieFixtures.framedNode(branch), CanonicalTrieFixtures.framedNode(leaf)
        );
    }

    function _frameEnd(
        bytes memory _encoded,
        uint256 _offset
    )
        private
        pure
        returns (uint256 end_)
    {
        uint256 length = (uint256(uint8(_encoded[_offset])) << 8) | uint8(_encoded[_offset + 1]);
        return _offset + 2 + length;
    }

    function _slice(
        bytes memory _input,
        uint256 _start,
        uint256 _end
    )
        private
        pure
        returns (bytes memory output_)
    {
        output_ = new bytes(_end - _start);
        for (uint256 i; i < output_.length; ++i) {
            output_[i] = _input[_start + i];
        }
    }
}
