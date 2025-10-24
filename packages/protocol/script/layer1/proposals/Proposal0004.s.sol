// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data: `P=0004 pnpm proposal`
// To dryrun the proposal on L1: `P=0004 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0004 pnpm proposal:dryrun:l2`
contract Proposal0004 is BuildProposal {
    // L1 contracts
    address public constant SP1_VERIFIER = 0xbee1040D0Aab17AE19454384904525aE4A3602B9;
    address public constant RISC0_VERIFIER = 0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE;
    address public constant RISC0_VERIFIER_NEW_IMPL = 0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36;
    address public constant PRECONF_ROUTER = 0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a;
    address public constant PRECONF_ROUTER_NEW_IMPL = 0xafCEDDe020dB8D431Fa86dF6B14C20f327382709;
    address public constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;
    address public constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](11);

        // SP1 Verifier Actions (4 calls)
        actions[0] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e, true)
            )
        });

        actions[1] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e, true)
            )
        });

        actions[2] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x00a32a15ab7a74a9a79f3b97a71d1b014cd4361b37819004b9322b502b5f5be1, true)
            )
        });

        actions[3] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                SP1Verifier.setProgramTrusted,
                (0x51950ad55e9d2a6973e772f471d1b01466a1b0d95e064012726456a02b5f5be1, true)
            )
        });

        // Risc0 Verifier Actions (2 calls) - using raw hex because image IDs are 33 bytes (exceed
        // bytes32 limit)
        actions[4] = Controller.Action({
            target: RISC0_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x3d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3, true)
            )
        });

        actions[5] = Controller.Action({
            target: RISC0_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                Risc0Verifier.setImageIdTrusted,
                (0x77ff0953ded4fb48bb52b1099cc36c6b8bf603dc4ed9211608c039c7ec31b82b, true)
            )
        });

        // Upgrade Risc0 Verifier to new implementation
        actions[6] = buildUpgradeAction(RISC0_VERIFIER, RISC0_VERIFIER_NEW_IMPL);

        // Upgrade PreconfRouter
        actions[7] = buildUpgradeAction(PRECONF_ROUTER, PRECONF_ROUTER_NEW_IMPL);

        actions[8] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0x3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0,
                true
            )
        });

        actions[9] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0xe5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a,
                true
            )
        });

        actions[10] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeWithSignature(
                "setMrEnclave(bytes32,bool)",
                0x605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f,
                true
            )
        });
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        l2ExecutionId = 0;
        l2GasLimit = 0;
        actions = new Controller.Action[](0);
    }
}
