// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data: `P=0019 pnpm proposal`
// To dryrun the proposal on L1: `P=0019 pnpm proposal:dryrun:l1`
contract Proposal0019 is BuildProposal {
    // Deployed mainnet implementation addresses.
    // TODO(unzen): fill in after running DeployUnzenContracts (FOUNDRY_PROFILE=layer1), then
    // update Proposal0019.md. The build reverts while these are zero so the action file cannot
    // be generated with placeholder addresses.
    address public constant MAINNET_INBOX_NEW_IMPL = address(0);

    // New ZkRequiredVerifier: (SGX_GETH or SGX_RETH) + (RISC0 or SP1), or RISC0 + SP1. Every
    // accepted combination contains at least one ZK proof. Baked into MAINNET_INBOX_NEW_IMPL as
    // an immutable; listed here for documentation and verification only.
    // TODO(unzen): fill in after running DeployUnzenContracts.
    address public constant ZK_REQUIRED_VERIFIER = address(0);

    // SGX sub-verifiers wired into ZK_REQUIRED_VERIFIER: the verifiers Proposal0017 deployed,
    // reused unchanged. Both are already owned by the DAO controller and each carries a
    // registered raiko instance, so this proposal neither configures trust nor accepts
    // ownership. Baked into ZK_REQUIRED_VERIFIER as immutables; listed here so a reviewer can
    // cross-check them against sgxGethVerifier()/sgxRethVerifier() on the deployed verifier.
    address public constant SGXGETH_VERIFIER = 0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee;
    address public constant SGXRETH_VERIFIER = 0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8;

    // ZK sub-verifiers wired into ZK_REQUIRED_VERIFIER (reused from Proposal0017, live on mainnet).
    address public constant RISC0_RETH_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address public constant SP1_RETH_VERIFIER = 0x73A0Db393ef87ce781ac7957bE10D6628432100F;

    // Currently trusted raiko2 v0.5.1 ZK IDs, set by Proposal0017 (verified still live on
    // 2026-07-08 via isImageTrusted/isProgramTrusted). Untrusted by this proposal: proofs from
    // the old raiko2 images stop verifying at execution.
    bytes32 public constant OLD_RISC0_PROPOSAL_IMAGE_ID =
        0xa38d1fac63aa6a553fdb6fea01fdc96534564c31de916aaafe5f5a1dd3bb908b;
    bytes32 public constant OLD_RISC0_AGGREGATION_IMAGE_ID =
        0x868b5154ae01a9a045051da2d7ba2e21d4132c7ec096da343fa24149407fefef;
    bytes32 public constant OLD_SP1_PROPOSAL_PROGRAM_VKEY_BN256 =
        0x007594632ec31fae9d44799b97316fcbcaa3ff6b5db268c7a5d8025b3bbb487e;
    bytes32 public constant OLD_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES =
        0x3aca319730c7eba7288f33727316fcbc551ffb5a76c9a31e4bb004b63bbb487e;
    bytes32 public constant OLD_SP1_AGGREGATION_PROGRAM_VKEY_BN256 =
        0x00e91cb391c22d6fd015e4c6041dbbe6efb2d8be6d4046eec28f12acba5a17bc;
    bytes32 public constant OLD_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES =
        0x748e59c8708b5bf402bc98c041dbbe6e7d96c5f335011bbb051e25593a5a17bc;

    // New raiko2 ZK IDs trusted by this proposal (the raiko release shipping with Unzen).
    // TODO(unzen): fill in from the release, then update Proposal0019.md and regenerate the
    // action file. The build reverts while these are zero.
    bytes32 public constant NEW_RISC0_PROPOSAL_IMAGE_ID = bytes32(0);
    bytes32 public constant NEW_RISC0_AGGREGATION_IMAGE_ID = bytes32(0);
    bytes32 public constant NEW_SP1_PROPOSAL_PROGRAM_VKEY_BN256 = bytes32(0);
    bytes32 public constant NEW_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES = bytes32(0);
    bytes32 public constant NEW_SP1_AGGREGATION_PROGRAM_VKEY_BN256 = bytes32(0);
    bytes32 public constant NEW_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES = bytes32(0);

    error ImplementationNotDeployed();
    error ZkImageIdNotSet();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        require(MAINNET_INBOX_NEW_IMPL != address(0), ImplementationNotDeployed());
        require(ZK_REQUIRED_VERIFIER != address(0), ImplementationNotDeployed());
        require(
            NEW_RISC0_PROPOSAL_IMAGE_ID != bytes32(0)
                && NEW_RISC0_AGGREGATION_IMAGE_ID != bytes32(0),
            ZkImageIdNotSet()
        );
        require(
            NEW_SP1_PROPOSAL_PROGRAM_VKEY_BN256 != bytes32(0)
                && NEW_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES != bytes32(0)
                && NEW_SP1_AGGREGATION_PROGRAM_VKEY_BN256 != bytes32(0)
                && NEW_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES != bytes32(0),
            ZkImageIdNotSet()
        );

        actions = new Controller.Action[](14);

        // 0-3: Rotate the trusted RISC0 image IDs to the Unzen raiko release. Untrust the live
        // raiko2 v0.5.1 IDs, trust the new ones. Proofs aggregated under the old images stop
        // verifying at execution, so the raiko2 service running the new images must be live
        // (and the prover pointed at it) when the proposal executes.
        actions[0] = Controller.Action({
            target: RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (OLD_RISC0_PROPOSAL_IMAGE_ID, false)
            )
        });
        actions[1] = Controller.Action({
            target: RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (OLD_RISC0_AGGREGATION_IMAGE_ID, false)
            )
        });
        actions[2] = Controller.Action({
            target: RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (NEW_RISC0_PROPOSAL_IMAGE_ID, true)
            )
        });
        actions[3] = Controller.Action({
            target: RISC0_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted, (NEW_RISC0_AGGREGATION_IMAGE_ID, true)
            )
        });

        // 4-11: Rotate the trusted SP1 program verification keys the same way.
        actions[4] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (OLD_SP1_PROPOSAL_PROGRAM_VKEY_BN256, false)
            )
        });
        actions[5] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (OLD_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, false)
            )
        });
        actions[6] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (OLD_SP1_AGGREGATION_PROGRAM_VKEY_BN256, false)
            )
        });
        actions[7] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (OLD_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, false)
            )
        });
        actions[8] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (NEW_SP1_PROPOSAL_PROGRAM_VKEY_BN256, true)
            )
        });
        actions[9] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (NEW_SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true)
            )
        });
        actions[10] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (NEW_SP1_AGGREGATION_PROGRAM_VKEY_BN256, true)
            )
        });
        actions[11] = Controller.Action({
            target: SP1_RETH_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted, (NEW_SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)
            )
        });

        // 12: Upgrade the Inbox to the Unzen implementation: forced inclusions re-enabled
        // (submission + mandatory processing of due inclusions) and the ZkRequiredVerifier
        // (at least one ZK proof per batch, SGX paths via the new hardened verifiers) baked in
        // as the proof verifier.
        actions[12] = buildUpgradeAction(L1.INBOX, MAINNET_INBOX_NEW_IMPL);

        // 13: Void the stale forced inclusion queue entry (head=2, tail=3) queued during the
        // June 2026 incident. Its blob has expired from the blob retention window and can no
        // longer be derived, so it must be skipped before the due-check is re-enabled.
        actions[13] = Controller.Action({
            target: L1.INBOX, value: 0, data: abi.encodeCall(IProposal0019Inbox.init3, ())
        });
    }
}

interface IProposal0019Inbox {
    function init3() external;
}
