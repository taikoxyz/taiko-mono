// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "../src/lib/OwnableUpgradeable.sol";
import {Shadow} from "../src/impl/Shadow.sol";
import {IShadow} from "../src/iface/IShadow.sol";
import {ShadowVerifier} from "../src/impl/ShadowVerifier.sol";
import {MockCircuitVerifier} from "./mocks/MockCircuitVerifier.sol";
import {MockEtherMinter} from "./mocks/MockEtherMinter.sol";
import {MockCheckpointStore} from "./mocks/MockCheckpointStore.sol";

contract ShadowTest is Test {
    MockCheckpointStore internal checkpointStore;
    MockCircuitVerifier internal circuitVerifier;
    ShadowVerifier internal shadowVerifier;
    MockEtherMinter internal etherMinter;
    Shadow internal shadow;

    function setUp() public {
        checkpointStore = new MockCheckpointStore();
        circuitVerifier = new MockCircuitVerifier();
        shadowVerifier = new ShadowVerifier(address(checkpointStore), address(circuitVerifier));
        etherMinter = new MockEtherMinter();

        Shadow shadowImpl = new Shadow(address(shadowVerifier), address(etherMinter));
        ERC1967Proxy shadowProxy = new ERC1967Proxy(
            address(shadowImpl),
            abi.encodeCall(Shadow.initialize, (address(this)))
        );
        shadow = Shadow(address(shadowProxy));
    }

    function test_constructor_RevertWhen_VerifierIsZeroAddress() external {
        vm.expectRevert(OwnableUpgradeable.ZeroAddress.selector);
        new Shadow(address(0), address(etherMinter));
    }

    function test_constructor_RevertWhen_EtherMinterIsZeroAddress() external {
        vm.expectRevert(OwnableUpgradeable.ZeroAddress.selector);
        new Shadow(address(shadowVerifier), address(0));
    }

    function test_claim_succeeds() external {
        uint48 blockNumber = 100;
        bytes32 stateRoot = keccak256("root");
        checkpointStore.setCheckpoint(blockNumber, bytes32(0), stateRoot);

        address recipient = address(0xBEEF);
        bytes32 nullifierValue = keccak256("nullifier");
        uint256 amount = 1 ether;
        bytes32 powDigest = bytes32(uint256(1) << 24);

        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: stateRoot,
            chainId: block.chainid,
            noteIndex: 1,
            amount: amount,
            recipient: recipient,
            nullifier: nullifierValue,
            powDigest: powDigest
        });

        shadow.claim("", input);
        assertEq(etherMinter.lastRecipient(), recipient);
        assertEq(etherMinter.lastAmount(), amount);
        assertTrue(shadow.isConsumed(nullifierValue));
    }

    function test_claim_RevertWhen_ChainIdMismatch() external {
        uint48 blockNumber = 100;
        bytes32 stateRoot = keccak256("root");
        checkpointStore.setCheckpoint(blockNumber, bytes32(0), stateRoot);

        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: stateRoot,
            chainId: block.chainid + 1,
            noteIndex: 1,
            amount: 1 ether,
            recipient: address(0xBEEF),
            nullifier: keccak256("nullifier"),
            powDigest: bytes32(uint256(1) << 24)
        });

        vm.expectRevert(abi.encodeWithSelector(IShadow.ChainIdMismatch.selector, block.chainid + 1, block.chainid));
        shadow.claim("", input);
    }

    function test_claim_RevertWhen_PowInvalid() external {
        uint48 blockNumber = 100;
        bytes32 stateRoot = keccak256("root");
        checkpointStore.setCheckpoint(blockNumber, bytes32(0), stateRoot);

        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: stateRoot,
            chainId: block.chainid,
            noteIndex: 1,
            amount: 1 ether,
            recipient: address(0xBEEF),
            nullifier: keccak256("nullifier"),
            powDigest: bytes32(uint256(1))
        });

        vm.expectRevert(abi.encodeWithSelector(IShadow.InvalidPowDigest.selector, bytes32(uint256(1))));
        shadow.claim("", input);
    }

    function test_claim_RevertWhen_ProofVerificationFailed() external {
        uint48 blockNumber = 100;
        bytes32 stateRoot = keccak256("root");
        checkpointStore.setCheckpoint(blockNumber, bytes32(0), stateRoot);
        circuitVerifier.setShouldVerify(false);

        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: stateRoot,
            chainId: block.chainid,
            noteIndex: 1,
            amount: 1 ether,
            recipient: address(0xBEEF),
            nullifier: keccak256("nullifier"),
            powDigest: bytes32(uint256(1) << 24)
        });

        vm.expectRevert(IShadow.ProofVerificationFailed.selector);
        shadow.claim("", input);
    }

    function test_claim_RevertWhen_NullifierReused() external {
        uint48 blockNumber = 100;
        bytes32 stateRoot = keccak256("root");
        checkpointStore.setCheckpoint(blockNumber, bytes32(0), stateRoot);

        bytes32 nullifierValue = keccak256("nullifier");
        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: stateRoot,
            chainId: block.chainid,
            noteIndex: 1,
            amount: 1 ether,
            recipient: address(0xBEEF),
            nullifier: nullifierValue,
            powDigest: bytes32(uint256(1) << 24)
        });

        shadow.claim("", input);
        vm.expectRevert(abi.encodeWithSelector(IShadow.NullifierAlreadyConsumed.selector, nullifierValue));
        shadow.claim("", input);
    }

    function test_claim_RevertWhen_InvalidRecipient() external {
        uint48 blockNumber = 100;
        bytes32 stateRoot = keccak256("root");
        checkpointStore.setCheckpoint(blockNumber, bytes32(0), stateRoot);

        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: stateRoot,
            chainId: block.chainid,
            noteIndex: 1,
            amount: 1 ether,
            recipient: address(0),
            nullifier: keccak256("nullifier"),
            powDigest: bytes32(uint256(1) << 24)
        });

        vm.expectRevert(abi.encodeWithSelector(IShadow.InvalidRecipient.selector, address(0)));
        shadow.claim("", input);
    }

    function test_claim_RevertWhen_InvalidAmount() external {
        uint48 blockNumber = 100;
        bytes32 stateRoot = keccak256("root");
        checkpointStore.setCheckpoint(blockNumber, bytes32(0), stateRoot);

        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: stateRoot,
            chainId: block.chainid,
            noteIndex: 1,
            amount: 0,
            recipient: address(0xBEEF),
            nullifier: keccak256("nullifier"),
            powDigest: bytes32(uint256(1) << 24)
        });

        vm.expectRevert(abi.encodeWithSelector(IShadow.InvalidAmount.selector, 0));
        shadow.claim("", input);
    }

    function test_isConsumed_returnsFalse_WhenNotConsumed() external view {
        assertFalse(shadow.isConsumed(keccak256("unused")));
    }

    function test_transferOwnership_succeeds() external {
        address newOwner = address(0x1234);
        shadow.transferOwnership(newOwner);
        assertEq(shadow.pendingOwner(), newOwner);

        vm.prank(newOwner);
        shadow.acceptOwnership();
        assertEq(shadow.owner(), newOwner);
    }
}
