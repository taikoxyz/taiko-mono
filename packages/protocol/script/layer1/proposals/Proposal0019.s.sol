// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0019 pnpm proposal`
// To dryrun the proposal on L1: `P=0019 pnpm proposal:dryrun:l1`
contract Proposal0019 is BuildProposal {
    // Deployed mainnet implementation addresses.
    // TODO(unzen): fill in after running DeployAutomataDcapAttestation (FOUNDRY_PROFILE=layer1o)
    // and then DeployUnzenContracts, then update Proposal0019.md. The build reverts while these
    // are zero so the action file cannot be generated with placeholder addresses.
    address public constant MAINNET_INBOX_NEW_IMPL = address(0);

    // New ZkRequiredVerifier: SGX_RETH + (RISC0 or SP1), or RISC0 + SP1. Every accepted
    // combination contains at least one ZK proof. Baked into MAINNET_INBOX_NEW_IMPL as an
    // immutable; listed here for documentation and verification only.
    // TODO(unzen): fill in after running DeployUnzenContracts.
    address public constant ZK_REQUIRED_VERIFIER = address(0);

    // NEW SGX SecureSgxVerifiers (geth + reth), each wired (immutably) to the audited upstream
    // Automata DCAP attestation entrypoint (DCAP_ATTESTATION below) and carrying the post-v3.1.0
    // hardening (permanent untrust, uint32 id overflow rejection, quote-freshness gate). They
    // replace the Proposal0017 verifiers (0x41e79EB4... geth, 0x9D3C595B... reth), which are
    // immutably wired to the old pre-incident vendored attestation. Trust configuration for both
    // is part of this proposal; instance registration happens post-execution via the registrar.
    // TODO(unzen): fill in after running DeployUnzenContracts.
    address public constant SGXGETH_VERIFIER_NEW = address(0);
    address public constant SGXRETH_VERIFIER_NEW = address(0);

    // Upstream Automata DCAP attestation entrypoint (AutomataDcapAttestationFee), baked into
    // SGXRETH_VERIFIER_NEW as an immutable; listed for documentation and verification only.
    // TODO(unzen): fill in after running DeployAutomataDcapAttestation.
    address public constant DCAP_ATTESTATION = address(0);

    // ZK sub-verifiers wired into ZK_REQUIRED_VERIFIER (reused from Proposal0017, live on mainnet).
    address public constant RISC0_RETH_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address public constant SP1_RETH_VERIFIER = 0x73A0Db393ef87ce781ac7957bE10D6628432100F;

    // Trusted raiko measurements for the new SGX verifiers. These are exactly the values
    // live-trusted on the Proposal0017 attesters (read from MrEnclaveUpdated/MrSignerUpdated
    // events on SGXGETH_ATTESTER 0x0ffa4A62... and SGXRETH_ATTESTER 0x8d7C9549..., set at
    // Proposal0017 execution, L1 block 25,423,573; unchanged since). The raiko images do not
    // change in this proposal, only the verifier contracts, so the measurements carry over
    // verbatim. Both flavors share one raiko signing identity (same MRSIGNER).
    bytes32 public constant TRUSTED_MR_ENCLAVE_GETH =
        0xbefb2c7ec44cefe57f4ff0ca815a8b8f15e05631bf3abe36cbc12d28f778fa36;
    bytes32 public constant TRUSTED_MR_ENCLAVE_RETH_1 =
        0xdccd8f30ea4a137ddfa63d743e3aa7c7a8e80585912d19c4b66f7d8d6098bec4;
    bytes32 public constant TRUSTED_MR_ENCLAVE_RETH_2 =
        0x92dd96a170d1ffb998afa210b3ef8af8c408ab76c4717e0eb8076d4a5da4e740;
    bytes32 public constant TRUSTED_MR_SIGNER =
        0x48fa5bbad91d274735d238715913c8712a7505bb6d0dd832764bedb46d587013;

    error ImplementationNotDeployed();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        require(MAINNET_INBOX_NEW_IMPL != address(0), ImplementationNotDeployed());
        require(SGXGETH_VERIFIER_NEW != address(0), ImplementationNotDeployed());
        require(SGXRETH_VERIFIER_NEW != address(0), ImplementationNotDeployed());

        actions = new Controller.Action[](7);

        // 0-4: Configure the trust registries of the new SGX verifiers. Both deploy fail-closed
        // (checkLocalEnclaveReport enabled, empty allowlists), so without these actions no SGX
        // instance can ever register. The DAO controller owns the verifiers, so these must be
        // proposal actions. Registration itself happens post-execution: the registrar
        // (admin.taiko.eth) calls registerInstance with fresh quotes, verified through the
        // upstream attestation entrypoint. Until then ZkRequiredVerifier's RISC0+SP1 path keeps
        // proving alive — no proving halt, unlike Proposal0017.
        actions[0] = Controller.Action({
            target: SGXGETH_VERIFIER_NEW,
            value: 0,
            data: abi.encodeCall(
                IProposal0019SgxVerifier.setMrEnclave, (TRUSTED_MR_ENCLAVE_GETH, true)
            )
        });
        actions[1] = Controller.Action({
            target: SGXGETH_VERIFIER_NEW,
            value: 0,
            data: abi.encodeCall(IProposal0019SgxVerifier.setMrSigner, (TRUSTED_MR_SIGNER, true))
        });
        actions[2] = Controller.Action({
            target: SGXRETH_VERIFIER_NEW,
            value: 0,
            data: abi.encodeCall(
                IProposal0019SgxVerifier.setMrEnclave, (TRUSTED_MR_ENCLAVE_RETH_1, true)
            )
        });
        actions[3] = Controller.Action({
            target: SGXRETH_VERIFIER_NEW,
            value: 0,
            data: abi.encodeCall(
                IProposal0019SgxVerifier.setMrEnclave, (TRUSTED_MR_ENCLAVE_RETH_2, true)
            )
        });
        actions[4] = Controller.Action({
            target: SGXRETH_VERIFIER_NEW,
            value: 0,
            data: abi.encodeCall(IProposal0019SgxVerifier.setMrSigner, (TRUSTED_MR_SIGNER, true))
        });

        // 5: Upgrade the Inbox to the Unzen implementation: forced inclusions re-enabled
        // (submission + mandatory processing of due inclusions) and the ZkRequiredVerifier
        // (at least one ZK proof per batch, SGX paths via the new hardened verifiers) baked in
        // as the proof verifier.
        actions[5] = buildUpgradeAction(L1.INBOX, MAINNET_INBOX_NEW_IMPL);

        // 6: Void the stale forced inclusion queue entry (head=2, tail=3) queued during the
        // June 2026 incident. Its blob has expired from the blob retention window and can no
        // longer be derived, so it must be skipped before the due-check is re-enabled.
        actions[6] = Controller.Action({
            target: L1.INBOX, value: 0, data: abi.encodeCall(IProposal0019Inbox.init3, ())
        });
    }
}

interface IProposal0019Inbox {
    function init3() external;
}

interface IProposal0019SgxVerifier {
    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external;
    function setMrSigner(bytes32 _mrSigner, bool _trusted) external;
}
