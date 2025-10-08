// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/libs/LibL1Addrs.sol";
import "src/layer1/verifiers/TaikoSP1Verifier.sol";
import "src/layer1/verifiers/TaikoRisc0Verifier.sol";

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

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](8);

        // SP1 Verifier Actions (4 calls)
        actions[0] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                TaikoSP1Verifier.setProgramTrusted,
                (0x008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e, true)
            )
        });

        actions[1] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                TaikoSP1Verifier.setProgramTrusted,
                (0x47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e, true)
            )
        });

        actions[2] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                TaikoSP1Verifier.setProgramTrusted,
                (0x004775b86041915596830bbc5464584165b2641a277b6758e83723954946bee2, true)
            )
        });

        actions[3] = Controller.Action({
            target: SP1_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                TaikoSP1Verifier.setProgramTrusted,
                (0x23badc30106455655061778a464584162d9320d11ded9d63506e472a4946bee2, true)
            )
        });

        // Risc0 Verifier Actions (2 calls) - using raw hex because image IDs are 33 bytes (exceed
        // bytes32 limit)
        actions[4] = Controller.Action({
            target: RISC0_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                TaikoRisc0Verifier.setImageIdTrusted,
                (0x3d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3, true)
            )
        });

        actions[5] = Controller.Action({
            target: RISC0_VERIFIER,
            value: 0,
            data: abi.encodeCall(
                TaikoRisc0Verifier.setImageIdTrusted,
                (0x326ce3b6f13708a0691ed4bc56e8c14d6ee4e1197c533c129b441e263350b87e, true)
            )
        });

        // Upgrade Risc0 Verifier to new implementation
        actions[6] = buildUpgradeAction(RISC0_VERIFIER, RISC0_VERIFIER_NEW_IMPL);

        // Upgrade PreconfRouter
        actions[7] = buildUpgradeAction(PRECONF_ROUTER, PRECONF_ROUTER_NEW_IMPL);
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
