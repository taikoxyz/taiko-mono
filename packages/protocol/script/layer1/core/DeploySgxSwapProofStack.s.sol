// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { ZkRequiredVerifier } from "src/layer1/verifiers/compose/ZkRequiredVerifier.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeploySgxSwapProofStack
/// @notice Ethereum-mainnet SGX-verifier swap: deploys two fresh `SecureSgxVerifier`s wired to a
/// pre-deployed Taiko-owned `AutomataDcapAttestationFee` entrypoint (env `DCAP_ATTESTATION`, itself
/// pointed at the on-chain PCCS router), a new `ZkRequiredVerifier` that composes them with the
/// live RISC0 + SP1 verifiers (reused, not redeployed), and a new `MainnetInbox` implementation
/// identical to the Proposal0019 impl (`0x5253d4c9…`) except its `proofVerifier`.
/// @dev Deploys implementations only — it does NOT touch the live `INBOX` proxy. After this runs,
/// the DAO controller must `upgradeTo(inboxImpl)` on `LibL1Addrs.INBOX`, and the registrar must
/// pin each new SGX enclave's attribute policy (`setEnclaveAttributePolicy`) and `registerInstance`
/// on the two new SGX verifiers. The entrypoint (`DeployAutomataDcapAttestation`, profile `layer1o`)
/// must be deployed first; everything here compiles under `FOUNDRY_PROFILE=layer1`.
/// @custom:security-contact security@taiko.xyz
contract DeploySgxSwapProofStack is Script {
    /// @dev Instance-validity monitoring delay for the new SGX verifiers (matches
    /// DeployMainnetProofStack).
    uint64 internal constant VALIDITY_DELAY = 24 hours;

    /// @dev The Proposal0019 (Unzen) mainnet inbox implementation whose config the new impl clones.
    address internal constant PROPOSAL0019_INBOX_IMPL = 0x5253D4C91e80b880DdB54B78E74082Abe066F6b9;

    /// @dev The Proposal0019 ZkRequiredVerifier the new one replaces (kept for the sanity cross-check
    /// and to document which SGX verifiers are being swapped out).
    address internal constant PROPOSAL0019_ZK_REQUIRED_VERIFIER =
        0x7284aaC05555Ae6559bdAd8B4221eC9584254Eec;

    struct SwapStack {
        address sgxGeth;
        address sgxReth;
        address zkRequiredVerifier;
        address inboxImpl;
    }

    /// @notice Deploys the SGX swap stack (2 SGX verifiers + ZkRequiredVerifier + MainnetInbox impl).
    /// @return stack_ The deployed implementation addresses.
    function run() external returns (SwapStack memory stack_) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address dcapAttestation = vm.envAddress("DCAP_ATTESTATION");
        require(dcapAttestation != address(0), "DCAP_ATTESTATION not set");

        // The registrar is the only address allowed to call `registerInstance`. Defaults to the live
        // production registrar (the address that operates the current SGX verifiers); override with
        // SGX_REGISTRAR, or set address(0) for permissionless registration.
        address registrar = vm.envOr("SGX_REGISTRAR", LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH);

        // The reference impl the new one must match (config-wise) except for the proof verifier.
        address referenceImpl = vm.envOr("REFERENCE_INBOX_IMPL", PROPOSAL0019_INBOX_IMPL);

        vm.startBroadcast(privateKey);

        // 1) Two fresh SGX verifiers, both wired to the one Taiko-owned Automata DCAP entrypoint
        //    (the #21827 shared-entrypoint model), owned by the DAO controller.
        stack_.sgxGeth = address(
            new SecureSgxVerifier(
                LibNetwork.TAIKO_MAINNET,
                LibL1Addrs.DAO_CONTROLLER,
                dcapAttestation,
                registrar,
                VALIDITY_DELAY
            )
        );
        stack_.sgxReth = address(
            new SecureSgxVerifier(
                LibNetwork.TAIKO_MAINNET,
                LibL1Addrs.DAO_CONTROLLER,
                dcapAttestation,
                registrar,
                VALIDITY_DELAY
            )
        );

        // 2) New ZkRequiredVerifier composing the new SGX verifiers with the LIVE RISC0 + SP1
        //    verifiers (reused as-is — they already carry the trusted image IDs / program keys).
        //    ComposeVerifier sub-verifiers are immutable, so a SGX change requires a new instance.
        stack_.zkRequiredVerifier = address(
            new ZkRequiredVerifier(
                stack_.sgxGeth,
                stack_.sgxReth,
                LibL1Addrs.RISC0_RETH_VERIFIER,
                LibL1Addrs.SP1_RETH_VERIFIER
            )
        );

        // 3) New MainnetInbox implementation. Its constructor hardcodes every numeric config field,
        //    so passing the same four peripheral addresses as Proposal0019 reproduces `0x5253d4c9…`
        //    exactly except `proofVerifier`. `Inbox._proofVerifier` is immutable, so a verifier
        //    change is only possible via a new impl + proxy upgrade.
        stack_.inboxImpl = address(
            new MainnetInbox(
                stack_.zkRequiredVerifier,
                LibL1Addrs.PRECONF_WHITELIST,
                LibL1Addrs.PROVER_WHITELIST,
                LibL1Addrs.SIGNAL_SERVICE,
                LibL1Addrs.TAIKO_TOKEN
            )
        );

        vm.stopBroadcast();

        // Guard: the new impl must be config-identical to the Proposal0019 impl except proofVerifier.
        _assertOnlyProofVerifierChanged(referenceImpl, stack_.inboxImpl, stack_.zkRequiredVerifier);

        console2.log("SgxGethVerifier deployed:", stack_.sgxGeth);
        console2.log("SgxRethVerifier deployed:", stack_.sgxReth);
        console2.log("ZkRequiredVerifier deployed:", stack_.zkRequiredVerifier);
        console2.log("MainnetInbox impl deployed:", stack_.inboxImpl);
        console2.log("  reused RISC0_RETH_VERIFIER:", LibL1Addrs.RISC0_RETH_VERIFIER);
        console2.log("  reused SP1_RETH_VERIFIER:", LibL1Addrs.SP1_RETH_VERIFIER);
        console2.log("  -> DAO must upgradeTo() this impl on INBOX:", LibL1Addrs.INBOX);
    }

    /// @dev Reverts unless `_newImpl`'s config equals `_reference`'s config in every field except
    /// `proofVerifier`, which must equal `_expectedVerifier`. Catches drift between the MainnetInbox
    /// source and the deployed Proposal0019 impl before it reaches an upgrade proposal.
    /// @param _reference The Proposal0019 inbox impl to clone.
    /// @param _newImpl The freshly deployed inbox impl.
    /// @param _expectedVerifier The new ZkRequiredVerifier the new impl must point at.
    function _assertOnlyProofVerifierChanged(
        address _reference,
        address _newImpl,
        address _expectedVerifier
    )
        internal
        view
    {
        require(_reference.code.length != 0, "reference inbox impl has no code on this network");

        IInbox.Config memory refCfg = IInbox(_reference).getConfig();
        IInbox.Config memory newCfg = IInbox(_newImpl).getConfig();

        require(newCfg.proofVerifier == _expectedVerifier, "new impl proofVerifier mismatch");

        // Zero out the one field that is meant to differ, then require the rest to be identical.
        refCfg.proofVerifier = address(0);
        newCfg.proofVerifier = address(0);
        require(
            keccak256(abi.encode(refCfg)) == keccak256(abi.encode(newCfg)),
            "config drift vs Proposal0019 impl: only proofVerifier may change"
        );
    }
}
