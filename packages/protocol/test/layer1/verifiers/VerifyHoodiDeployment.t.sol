// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { VerifyHoodiDeployment } from "script/layer1/verifiers/VerifyHoodiDeployment.s.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import { MainnetVerifier } from "src/layer1/mainnet/MainnetVerifier.sol";
import { InsecureSgxVerifier } from "src/layer1/verifiers/InsecureSgxVerifier.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @dev An empty contract; used wherever a check only needs `code.length > 0`.
contract MockCoded { }

/// @dev Returns an IInbox.Config with only `proofVerifier` populated.
contract MockInbox {
    address internal immutable pv;

    constructor(address _pv) {
        pv = _pv;
    }

    function getConfig() external view returns (IInbox.Config memory c) {
        c.proofVerifier = pv;
    }
}

/// @dev Minimal AutomataDcapAttestationFee stand-in (the real one needs via_ir).
contract MockEntrypoint {
    address public owner;
    uint16 internal bp;
    bool internal stubAccept; // when true, empty-quote "succeeds" (a broken stub)
    mapping(uint16 => address) public quoteVerifiers;

    constructor(address _owner, uint16 _bp, address _v3) {
        owner = _owner;
        bp = _bp;
        quoteVerifiers[3] = _v3;
    }

    function getBp() external view returns (uint16) {
        return bp;
    }

    function setStubAccept(bool _v) external {
        stubAccept = _v;
    }

    function verifyAndAttestOnChain(bytes calldata) external payable returns (bool, bytes memory) {
        return (stubAccept, bytes("mock"));
    }
}

/// @dev Minimal V3QuoteVerifier stand-in.
contract MockV3 {
    address public pccsRouter;
    uint16 public quoteVersion = 3;

    constructor(address _pccs) {
        pccsRouter = _pccs;
    }
}

contract VerifyHoodiDeploymentTest is Test {
    address internal constant OWNER = LibL1HoodiAddrs.HOODI_CONTRACT_OWNER;
    uint64 internal constant CHAIN_ID = LibNetwork.TAIKO_HOODI;

    VerifyHoodiDeployment internal verifier;
    address internal goodInbox;
    address internal goodEntrypoint;

    function setUp() public {
        verifier = new VerifyHoodiDeployment();
        goodEntrypoint = _entrypoint(OWNER, 0);
        (goodInbox,) = _stack(goodEntrypoint, goodEntrypoint, false, CHAIN_ID, OWNER);
    }

    /// @dev Builds a correctly-wired AutomataDcapAttestationFee stand-in.
    function _entrypoint(address owner_, uint16 bp_) internal returns (address) {
        address pccs = address(new MockCoded());
        address v3 = address(new MockV3(pccs));
        return address(new MockEntrypoint(owner_, bp_, v3));
    }

    /// @dev Builds inbox -> MainnetVerifier -> {sgx x2, risc0, sp1}; SGX verifiers point at sgxAtt_.
    function _stack(
        address entrypoint_,
        address sgxAtt_,
        bool insecure_,
        uint64 sgxChainId_,
        address sgxOwner_
    )
        internal
        returns (address inbox_, address attestation_)
    {
        address reth = insecure_
            ? address(new InsecureSgxVerifier(sgxChainId_, sgxOwner_, sgxAtt_, address(0)))
            : address(new SecureSgxVerifier(sgxChainId_, sgxOwner_, sgxAtt_, address(0), 24 hours));
        address geth = insecure_
            ? address(new InsecureSgxVerifier(sgxChainId_, sgxOwner_, sgxAtt_, address(0)))
            : address(new SecureSgxVerifier(sgxChainId_, sgxOwner_, sgxAtt_, address(0), 24 hours));
        address risc0 = address(new Risc0Verifier(CHAIN_ID, address(new MockCoded()), OWNER));
        address sp1 = address(new SP1Verifier(CHAIN_ID, address(new MockCoded()), OWNER));
        address mv = address(new MainnetVerifier(geth, reth, risc0, sp1));
        inbox_ = address(new MockInbox(mv));
        attestation_ = entrypoint_;
    }

    function test_verify_happyPath_passes() public {
        assertEq(verifier.verify(goodInbox, goodEntrypoint, address(0)), 0);
    }

    function test_verify_entrypointWithoutCode_fails() public {
        // An EOA-style address (no code) as the attestation root trips the has-code check.
        assertGt(verifier.verify(goodInbox, address(0xEE), address(0)), 0);
    }

    function test_verify_entrypointWrongOwner_fails() public {
        address badEntry = _entrypoint(address(0xBAD), 0);
        (address inbox,) = _stack(badEntry, badEntry, false, CHAIN_ID, OWNER);
        assertGt(verifier.verify(inbox, badEntry, address(0)), 0);
    }

    function test_verify_entrypointNonZeroFee_fails() public {
        address badEntry = _entrypoint(OWNER, 100); // bp != 0
        (address inbox,) = _stack(badEntry, badEntry, false, CHAIN_ID, OWNER);
        assertGt(verifier.verify(inbox, badEntry, address(0)), 0);
    }

    function test_verify_entrypointStubLiveness_fails() public {
        // A stub entrypoint that "accepts" an empty quote must be caught by the liveness probe.
        MockEntrypoint(goodEntrypoint).setStubAccept(true);
        assertGt(verifier.verify(goodInbox, goodEntrypoint, address(0)), 0);
    }

    function test_verify_pccsMismatch_advisoryNotHardFail() public {
        // Supplying a wrong expected PCCS is an advisory: hardFails stays 0 on an otherwise-good stack.
        assertEq(verifier.verify(goodInbox, goodEntrypoint, address(0x9999)), 0);
    }

    function test_verify_insecureSgxPolicy_fails() public {
        // A public testnet must use SecureSgxVerifier; the lenient one must be rejected.
        (address inbox, address att) = _stack(goodEntrypoint, goodEntrypoint, true, CHAIN_ID, OWNER);
        assertGt(verifier.verify(inbox, att, address(0)), 0);
    }

    function test_verify_sgxWrongChainId_fails() public {
        (address inbox, address att) = _stack(goodEntrypoint, goodEntrypoint, false, 999, OWNER);
        assertGt(verifier.verify(inbox, att, address(0)), 0);
    }

    function test_verify_sgxWrongOwner_fails() public {
        (address inbox, address att) =
            _stack(goodEntrypoint, goodEntrypoint, false, CHAIN_ID, address(0xBAD));
        assertGt(verifier.verify(inbox, att, address(0)), 0);
    }

    function test_verify_sgxPointsAtWrongEntrypoint_fails() public {
        address other = _entrypoint(OWNER, 0);
        // SGX verifiers point at `other`, but we verify against `goodEntrypoint` as the root.
        (address inbox,) = _stack(goodEntrypoint, other, false, CHAIN_ID, OWNER);
        assertGt(verifier.verify(inbox, goodEntrypoint, address(0)), 0);
    }

    function test_verify_risc0WrongChainId_fails() public {
        // Build a stack whose Risc0 verifier has a wrong chain id.
        address reth =
            address(new SecureSgxVerifier(CHAIN_ID, OWNER, goodEntrypoint, address(0), 24 hours));
        address geth =
            address(new SecureSgxVerifier(CHAIN_ID, OWNER, goodEntrypoint, address(0), 24 hours));
        address risc0 = address(new Risc0Verifier(999, address(new MockCoded()), OWNER));
        address sp1 = address(new SP1Verifier(CHAIN_ID, address(new MockCoded()), OWNER));
        address mv = address(new MainnetVerifier(geth, reth, risc0, sp1));
        address inbox = address(new MockInbox(mv));
        assertGt(verifier.verify(inbox, goodEntrypoint, address(0)), 0);
    }

    function test_verify_sp1RemoteWithoutCode_fails() public {
        // SP1's remote verifier is an EOA (no code) -> has-code sub-check fails.
        address reth =
            address(new SecureSgxVerifier(CHAIN_ID, OWNER, goodEntrypoint, address(0), 24 hours));
        address geth =
            address(new SecureSgxVerifier(CHAIN_ID, OWNER, goodEntrypoint, address(0), 24 hours));
        address risc0 = address(new Risc0Verifier(CHAIN_ID, address(new MockCoded()), OWNER));
        address sp1 = address(new SP1Verifier(CHAIN_ID, address(0xEE), OWNER)); // 0xEE has no code
        address mv = address(new MainnetVerifier(geth, reth, risc0, sp1));
        address inbox = address(new MockInbox(mv));
        assertGt(verifier.verify(inbox, goodEntrypoint, address(0)), 0);
    }
}
