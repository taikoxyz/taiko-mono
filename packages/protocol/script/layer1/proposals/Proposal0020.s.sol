// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0020 pnpm proposal`
// To dryrun the proposal on L1: `P=0020 pnpm proposal:dryrun:l1`
//
// Stacks on Proposal0019 (Unzen), which MUST execute first: this proposal assumes 0019 has already
// rotated the RISC0/SP1 trusted IDs to raiko2 v0.6.0 on the reused ZK verifiers, run `init3`, and
// upgraded the Inbox to its own implementation. This proposal then moves the SGX legs onto a
// Taiko-owned, PCCS-backed Automata DCAP entrypoint and re-points the Inbox at a new
// ZkRequiredVerifier that composes the new SGX verifiers with those same reused ZK verifiers.
contract Proposal0020 is BuildProposal {
    // ---------------------------------------------------------------
    // New SGX stack, deployed 2026-07-16 at mainnet block 25543404 by
    // DeployAutomataDcapAttestation (profile layer1o) for the entrypoint and
    // DeploySgxSwapProofStack (profile layer1) for the rest. All addresses verified on-chain.
    // ---------------------------------------------------------------

    // The Taiko-owned Automata DCAP entrypoint both new SGX verifiers attest through. Its
    // V3QuoteVerifier reads Automata's on-chain PCCS router 0xE2Cd5aA4… (provisioned 2026-07-10).
    // Baked into both SGX verifiers as an immutable; listed for documentation/verification only.
    address public constant DCAP_ATTESTATION = 0x49216ad7d4DbafbE2F14525a863E621e2041ECB6;

    // The new SGX verifiers this proposal establishes trust on. Owned by the DAO controller;
    // registrar is MULTISIG_ADMIN_TAIKO_ETH (0x9CBeE534…), which registers instances afterwards.
    address public constant SGXGETH_VERIFIER = 0xA8A78d008b5745dd8487A8E912cD3d5A8618b496;
    address public constant SGXRETH_VERIFIER = 0x4bFaB16Bd9DA86bF6498a640B4d076eF4Ef5dfaA;

    // New ZkRequiredVerifier: (SGX_GETH or SGX_RETH) + (RISC0 or SP1), or RISC0 + SP1. Composes the
    // two new SGX verifiers above with the unchanged ZK verifiers below. Baked into
    // MAINNET_INBOX_NEW_IMPL as an immutable; listed so a reviewer can cross-check it against
    // sgxGethVerifier()/sgxRethVerifier()/risc0RethVerifier()/sp1RethVerifier() on the deployment.
    address public constant ZK_REQUIRED_VERIFIER = 0x0676334976D6578229829fAf92fb72Bd9378995b;

    // New Inbox implementation. Identical to the Proposal0019 implementation
    // (0x5253D4C9…) in every Config field except `proofVerifier`, which points at
    // ZK_REQUIRED_VERIFIER above. `Inbox._proofVerifier` is immutable, so swapping the verifier is
    // only possible via a new implementation plus this upgrade.
    address public constant MAINNET_INBOX_NEW_IMPL = 0x05C9620F9cc7154Ab1a47029014960e673586138;

    // ---------------------------------------------------------------
    // Reused unchanged (already carry the raiko2 v0.6.0 trust set that Proposal0019 installs)
    // ---------------------------------------------------------------
    address public constant RISC0_RETH_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address public constant SP1_RETH_VERIFIER = 0x73A0Db393ef87ce781ac7957bE10D6628432100F;

    // ---------------------------------------------------------------
    // Superseded by this proposal (documentation only — no action targets them)
    // ---------------------------------------------------------------

    // Proposal0019's verifier, composed from the SGX verifiers below. Orphaned once the Inbox
    // points at ZK_REQUIRED_VERIFIER: nothing reaches it, so its instances need no cleanup.
    address public constant OLD_ZK_REQUIRED_VERIFIER = 0x7284aaC05555Ae6559bdAd8B4221eC9584254Eec;
    // The Proposal0017 SGX verifiers, which attest through the legacy stripped attester proxies
    // (0x0ffa…/0x8d7C…) rather than a PCCS-backed DCAP entrypoint. Retired by this proposal.
    address public constant OLD_SGXGETH_VERIFIER = 0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee;
    address public constant OLD_SGXRETH_VERIFIER = 0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8;

    // ---------------------------------------------------------------
    // Trust values
    // ---------------------------------------------------------------

    // The authoritative raiko enclave signer (Proposal0017's NEW_MR_SIGNER), unchanged. The new
    // verifiers start with an empty allowlist, so it must be trusted explicitly here. The leaked
    // signer 0xca0583a7… is deliberately never trusted on these verifiers.
    bytes32 public constant MR_SIGNER =
        0x48fa5bbad91d274735d238715913c8712a7505bb6d0dd832764bedb46d587013;

    // raiko2 v0.6.0 TEE MRENCLAVE values — the same set Proposal0019 trusts on the legacy
    // attesters, re-established here on the new verifiers.
    // Source: https://github.com/taikoxyz/raiko2/releases/tag/v0.6.0
    bytes32 public constant SGXGETH_MR_ENCLAVE =
        0x2d2216efbe9d8e80ba24b86606ccd5ce9faf11033d31ad9e5d3c5c89965c8a57;
    bytes32 public constant SGXRETH_NON_EDMM_MR_ENCLAVE =
        0x90c79e65d6d0f83d658ff96cd0ef1204438f20b406c93cf1d4fafa0cff29842e;
    bytes32 public constant SGXRETH_EDMM_MR_ENCLAVE =
        0x041cadb0541bf8249c368482172d218608f3693975b65f74beb2ed6f0044f951;

    // The per-MRENCLAVE ATTRIBUTES pin required by SecureSgxVerifier: "Profile A — strict FLAGS pin"
    // from script/layer1/verifiers/enclave-attribute-policies.md, the documented default for both the
    // Raiko SGX-reth and SGX-geth prover enclaves and the pin exercised by the test suite
    // (SgxVerifier.t.sol STRICT_MASK / STRICT_EXPECTED).
    //
    // The mask checks all 8 FLAGS bytes and leaves XFRM (bytes 8-15) unchecked, so provers on hosts
    // with different XSAVE configurations (XFRM 0x03 / 0x07 / 0xE7) all satisfy one policy. The
    // expected value requires INIT(0x01) | MODE64BIT(0x04) and forces every other FLAGS bit to zero —
    // the forbidden floor, CET(0x40), KSS(0x80), AEX_NOTIFY(0x04 in byte 1) and all reserved bits.
    //
    // Both v0.6.0 enclaves attest with FLAGS = 0x05: raiko2's Gramine manifest sets sgx.debug=false
    // and enables no KSS/CET/AEX-Notify, and gaiko2 signs with EGo v1.9 (enclave.json "debug": false),
    // whose schema exposes no knob for those bits. EDMM does not set a FLAGS bit, so both SGX-reth
    // measurements share this pin.
    //
    // Re-pinning later bumps the policy version and revokes every instance registered under the old
    // pin, so reconcile against a real v0.6.0 quote (ATTRIBUTES = bytes [96:112] of the raw quote)
    // before submission — the SGX-geth/EGo side has no on-chain precedent to cross-check against.
    bytes16 public constant ENCLAVE_ATTRIBUTE_MASK = bytes16(0xffffffffffffffff0000000000000000);
    bytes16 public constant ENCLAVE_ATTRIBUTE_EXPECTED =
        bytes16(0x05000000000000000000000000000000);

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        require(MAINNET_INBOX_NEW_IMPL != address(0), ImplementationNotDeployed());
        require(ZK_REQUIRED_VERIFIER != address(0), ImplementationNotDeployed());
        require(
            SGXGETH_VERIFIER != address(0) && SGXRETH_VERIFIER != address(0),
            ImplementationNotDeployed()
        );
        require(MR_SIGNER != bytes32(0), MrSignerNotSet());
        require(
            SGXGETH_MR_ENCLAVE != bytes32(0) && SGXRETH_NON_EDMM_MR_ENCLAVE != bytes32(0)
                && SGXRETH_EDMM_MR_ENCLAVE != bytes32(0),
            SgxMrEnclaveNotSet()
        );
        // Fail closed while the ATTRIBUTES pin is unset: a zero mask is rejected on-chain by
        // setEnclaveAttributePolicy anyway, so this turns a guaranteed execution revert into a
        // build-time error.
        require(ENCLAVE_ATTRIBUTE_MASK != bytes16(0), AttributePolicyNotSet());

        actions = new Controller.Action[](9);

        // 0-2: Establish the SGX-geth trust set on the new verifier. The allowlist starts empty, so
        // signer, measurement and the ATTRIBUTES pin must all be set before the registrar can
        // register an instance (registration fail-closes without a pin).
        actions[0] = Controller.Action({
            target: SGXGETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(IProposal0020SgxVerifier.setMrSigner, (MR_SIGNER, true))
        });
        actions[1] = Controller.Action({
            target: SGXGETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(IProposal0020SgxVerifier.setMrEnclave, (SGXGETH_MR_ENCLAVE, true))
        });
        actions[2] = Controller.Action({
            target: SGXGETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                IProposal0020SgxVerifier.setEnclaveAttributePolicy,
                (SGXGETH_MR_ENCLAVE, ENCLAVE_ATTRIBUTE_MASK, ENCLAVE_ATTRIBUTE_EXPECTED)
            )
        });

        // 3-7: The same for SGX-reth, which allowlists two measurements (non-EDMM and EDMM builds).
        actions[3] = Controller.Action({
            target: SGXRETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(IProposal0020SgxVerifier.setMrSigner, (MR_SIGNER, true))
        });
        actions[4] = Controller.Action({
            target: SGXRETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                IProposal0020SgxVerifier.setMrEnclave, (SGXRETH_NON_EDMM_MR_ENCLAVE, true)
            )
        });
        actions[5] = Controller.Action({
            target: SGXRETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                IProposal0020SgxVerifier.setMrEnclave, (SGXRETH_EDMM_MR_ENCLAVE, true)
            )
        });
        actions[6] = Controller.Action({
            target: SGXRETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                IProposal0020SgxVerifier.setEnclaveAttributePolicy,
                (SGXRETH_NON_EDMM_MR_ENCLAVE, ENCLAVE_ATTRIBUTE_MASK, ENCLAVE_ATTRIBUTE_EXPECTED)
            )
        });
        actions[7] = Controller.Action({
            target: SGXRETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                IProposal0020SgxVerifier.setEnclaveAttributePolicy,
                (SGXRETH_EDMM_MR_ENCLAVE, ENCLAVE_ATTRIBUTE_MASK, ENCLAVE_ATTRIBUTE_EXPECTED)
            )
        });

        // 8: Re-point the Inbox at the new ZkRequiredVerifier by upgrading to an implementation
        // identical to Proposal0019's except its immutable proofVerifier. Until the registrar
        // registers instances on the new SGX verifiers, no SGX leg can verify and finalization
        // proceeds on the RISC0 + SP1 combination, which this verifier also accepts.
        actions[8] = buildUpgradeAction(L1.INBOX, MAINNET_INBOX_NEW_IMPL);
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error ImplementationNotDeployed();
    error MrSignerNotSet();
    error SgxMrEnclaveNotSet();
    error AttributePolicyNotSet();
}

interface IProposal0020SgxVerifier {
    function setMrSigner(bytes32 _mrSigner, bool _trusted) external;
    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external;
    function setEnclaveAttributePolicy(
        bytes32 _mrEnclave,
        bytes16 _mask,
        bytes16 _expected
    )
        external;
}
