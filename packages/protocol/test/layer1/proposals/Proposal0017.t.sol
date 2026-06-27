// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Test } from "forge-std/src/Test.sol";
import { Proposal0017 } from "script/layer1/proposals/Proposal0017.s.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";
import { Controller } from "src/shared/governance/Controller.sol";

/// @custom:security-contact security@taiko.xyz
contract Proposal0017Test is Test {
    address internal constant MAINNET_INBOX_NEW_IMPL = 0x1010101010101010101010101010101010101010;
    address internal constant SIGNAL_SERVICE_NEW_IMPL = 0x2020202020202020202020202020202020202020;
    address internal constant MAINNET_BRIDGE_NEW_IMPL = 0x3030303030303030303030303030303030303030;
    address internal constant MAINNET_ERC20_VAULT_NEW_IMPL =
        0x4040404040404040404040404040404040404040;

    address internal constant RISC0_RETH_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address internal constant SP1_RETH_VERIFIER = 0x73A0Db393ef87ce781ac7957bE10D6628432100F;
    address internal constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;
    address internal constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;

    bytes32 internal constant NEW_MR_SIGNER =
        0x48fa5bbad91d274735d238715913c8712a7505bb6d0dd832764bedb46d587013;
    bytes32 internal constant OLD_MR_SIGNER =
        0xca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5;
    bytes32 internal constant NEW_SGXGETH_MR_ENCLAVE =
        0xbefb2c7ec44cefe57f4ff0ca815a8b8f15e05631bf3abe36cbc12d28f778fa36;
    bytes32 internal constant NEW_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0xdccd8f30ea4a137ddfa63d743e3aa7c7a8e80585912d19c4b66f7d8d6098bec4;
    bytes32 internal constant NEW_SGXRETH_EDMM_MR_ENCLAVE =
        0x92dd96a170d1ffb998afa210b3ef8af8c408ab76c4717e0eb8076d4a5da4e740;
    bytes32 internal constant RISC0_PROPOSAL_IMAGE_ID =
        0xa38d1fac63aa6a553fdb6fea01fdc96534564c31de916aaafe5f5a1dd3bb908b;
    bytes32 internal constant RISC0_AGGREGATION_IMAGE_ID =
        0x868b5154ae01a9a045051da2d7ba2e21d4132c7ec096da343fa24149407fefef;
    bytes32 internal constant SP1_PROPOSAL_PROGRAM_VKEY_BN256 =
        0x007594632ec31fae9d44799b97316fcbcaa3ff6b5db268c7a5d8025b3bbb487e;
    bytes32 internal constant SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES =
        0x3aca319730c7eba7288f33727316fcbc551ffb5a76c9a31e4bb004b63bbb487e;
    bytes32 internal constant SP1_AGGREGATION_PROGRAM_VKEY_BN256 =
        0x00e91cb391c22d6fd015e4c6041dbbe6efb2d8be6d4046eec28f12acba5a17bc;
    bytes32 internal constant SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES =
        0x748e59c8708b5bf402bc98c041dbbe6e7d96c5f335011bbb051e25593a5a17bc;

    uint48 internal constant RECOVERY_LAST_FINALIZED_PROPOSAL_ID = 18_051;
    bytes32 internal constant RECOVERY_LAST_FINALIZED_BLOCK_HASH =
        0x64c2ada556b6862d2c8796e0f709c454fede9d03908711a9f04d9f9f9dcce470;

    function test_buildL1Actions_UsesDeployedImplementations() external {
        Proposal0017Harness proposal = new Proposal0017Harness();

        // All eight implementation addresses are now real, so the placeholder guard passes and the
        // no-arg path builds actions from the deployed implementation constants.
        Controller.Action[] memory actions = proposal.exposedBuildL1Actions();

        assertEq(actions.length, 56);

        // The proxy-upgrade actions carry the deployed implementation addresses.
        assertEq(actions[0].target, L1.SIGNAL_SERVICE);
        assertEq(
            actions[0].data,
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x1A06832992785766a105838C95c1E13a0045AC85))
        );

        assertEq(actions[1].target, L1.BRIDGE);
        assertEq(
            actions[1].data,
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x1c94D798CFA08F396E5BA9F81697289c53273381))
        );

        assertEq(actions[2].target, L1.ERC20_VAULT);
        assertEq(
            actions[2].data,
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x024253C6FDC27d3161aFd43fb0241411A28dDc3c))
        );

        assertEq(actions[4].target, L1.INBOX);
        assertEq(
            actions[4].data,
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x64523f2580f4E7038a121D55b220a9C12C1E8f01))
        );
    }

    function test_buildL1Actions_EncodesRecoverySequenceAndVerifierCleanup() external {
        Proposal0017Harness proposal = new Proposal0017Harness();

        Controller.Action[] memory actions = proposal.exposedBuildL1Actions({
            _mainnetInboxNewImpl: MAINNET_INBOX_NEW_IMPL,
            _signalServiceNewImpl: SIGNAL_SERVICE_NEW_IMPL,
            _mainnetBridgeNewImpl: MAINNET_BRIDGE_NEW_IMPL,
            _mainnetErc20VaultNewImpl: MAINNET_ERC20_VAULT_NEW_IMPL
        });

        uint256 cursor;

        assertEq(actions.length, 56);

        assertEq(actions[cursor].target, L1.SIGNAL_SERVICE);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (SIGNAL_SERVICE_NEW_IMPL))
        );

        assertEq(actions[cursor].target, L1.BRIDGE);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (MAINNET_BRIDGE_NEW_IMPL))
        );

        assertEq(actions[cursor].target, L1.ERC20_VAULT);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (MAINNET_ERC20_VAULT_NEW_IMPL))
        );

        assertEq(actions[cursor].target, L1.BRIDGE);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(IBridgeRecovery.init3, (_retriableMessageHashes()))
        );

        assertEq(actions[cursor].target, L1.INBOX);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (MAINNET_INBOX_NEW_IMPL))
        );

        assertEq(actions[cursor].target, L1.INBOX);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(
                IInboxRecovery.init2,
                (RECOVERY_LAST_FINALIZED_PROPOSAL_ID, RECOVERY_LAST_FINALIZED_BLOCK_HASH)
            )
        );

        assertEq(actions[cursor].target, SGXGETH_ATTESTER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(IAutomataAttestationRecovery.setMrSigner, (NEW_MR_SIGNER, true))
        );

        assertEq(actions[cursor].target, SGXRETH_ATTESTER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(IAutomataAttestationRecovery.setMrSigner, (NEW_MR_SIGNER, true))
        );

        assertEq(actions[cursor].target, SGXGETH_ATTESTER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(
                IAutomataAttestationRecovery.setMrEnclave, (NEW_SGXGETH_MR_ENCLAVE, true)
            )
        );

        assertEq(actions[cursor].target, SGXRETH_ATTESTER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(
                IAutomataAttestationRecovery.setMrEnclave, (NEW_SGXRETH_NON_EDMM_MR_ENCLAVE, true)
            )
        );

        assertEq(actions[cursor].target, SGXRETH_ATTESTER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(
                IAutomataAttestationRecovery.setMrEnclave, (NEW_SGXRETH_EDMM_MR_ENCLAVE, true)
            )
        );

        assertEq(actions[cursor].target, SGXGETH_ATTESTER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(IAutomataAttestationRecovery.setMrSigner, (OLD_MR_SIGNER, false))
        );

        assertEq(actions[cursor].target, SGXRETH_ATTESTER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(IAutomataAttestationRecovery.setMrSigner, (OLD_MR_SIGNER, false))
        );

        bytes32[] memory sgxGethMrEnclaves = _sgxGethMrEnclavesToDisable();
        for (uint256 i; i < sgxGethMrEnclaves.length; ++i) {
            assertEq(actions[cursor].target, SGXGETH_ATTESTER);
            assertEq(actions[cursor].value, 0);
            assertEq(
                actions[cursor++].data,
                abi.encodeCall(
                    IAutomataAttestationRecovery.setMrEnclave, (sgxGethMrEnclaves[i], false)
                )
            );
        }

        bytes32[] memory sgxRethMrEnclaves = _sgxRethMrEnclavesToDisable();
        for (uint256 i; i < sgxRethMrEnclaves.length; ++i) {
            assertEq(actions[cursor].target, SGXRETH_ATTESTER);
            assertEq(actions[cursor].value, 0);
            assertEq(
                actions[cursor++].data,
                abi.encodeCall(
                    IAutomataAttestationRecovery.setMrEnclave, (sgxRethMrEnclaves[i], false)
                )
            );
        }

        bytes32[] memory risc0ImageIds = _risc0ImageIdsToDisable();
        for (uint256 i; i < risc0ImageIds.length; ++i) {
            assertEq(actions[cursor].target, RISC0_RETH_VERIFIER);
            assertEq(actions[cursor].value, 0);
            assertEq(
                actions[cursor++].data,
                abi.encodeCall(Risc0Verifier.setImageIdTrusted, (risc0ImageIds[i], false))
            );
        }

        assertEq(actions[cursor].target, RISC0_RETH_VERIFIER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(Risc0Verifier.setImageIdTrusted, (RISC0_PROPOSAL_IMAGE_ID, true))
        );
        assertEq(actions[cursor].target, RISC0_RETH_VERIFIER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(Risc0Verifier.setImageIdTrusted, (RISC0_AGGREGATION_IMAGE_ID, true))
        );

        assertEq(actions[cursor].target, SP1_RETH_VERIFIER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(SP1Verifier.setProgramTrusted, (SP1_PROPOSAL_PROGRAM_VKEY_BN256, true))
        );
        assertEq(actions[cursor].target, SP1_RETH_VERIFIER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES, true)
            )
        );
        assertEq(actions[cursor].target, SP1_RETH_VERIFIER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_AGGREGATION_PROGRAM_VKEY_BN256, true)
            )
        );
        assertEq(actions[cursor].target, SP1_RETH_VERIFIER);
        assertEq(actions[cursor].value, 0);
        assertEq(
            actions[cursor++].data,
            abi.encodeCall(
                SP1Verifier.setProgramTrusted, (SP1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES, true)
            )
        );

        assertEq(cursor, actions.length);
    }

    function _retriableMessageHashes() private pure returns (bytes32[] memory hashes_) {
        hashes_ = new bytes32[](3);
        hashes_[0] = 0x997216448ef88e6398e82b0f003abb8637d25441ca6d22b09a65f63ef077480a;
        hashes_[1] = 0xf2994252987db0f55b6accdf1ff979bc508cd4acfcc229ad64b23a67f6fd984d;
        hashes_[2] = 0xea26be1009e743aec78e1f566e91db0b9fda29e16fec1e72e2d74c6983a68e70;
    }

    function _risc0ImageIdsToDisable() private pure returns (bytes32[] memory ids_) {
        ids_ = new bytes32[](6);
        ids_[0] = 0x26abb0237d10e891443e2a76bd3c1f6704c1ad03c07cb2165f4afcfc64b3cee7;
        ids_[1] = 0x46efe5e0c74976548ee6856789fbfb4929b8f2f9118a119c57ced6e1062e727b;
        ids_[2] = 0x779c032b91d0730ef13b26eafa47b32df7ebdaa4ed766d587fe905530afa2544;
        ids_[3] = 0xbee1be4cbe2bdf9b0034a1ab6572061a76019e73189ff96322e58ab229b75f92;
        ids_[4] = 0xcecc85819e15d173c2991577727525b136e820728f7aaaede612f1281cac2249;
        ids_[5] = 0xdfbce2039ad8b78b236b5a9dceba5d8cee0d9e4638fc8f1fe11a0b2d8bfa039e;
    }

    function _sgxGethMrEnclavesToDisable() private pure returns (bytes32[] memory ids_) {
        ids_ = new bytes32[](5);
        ids_[0] = 0x398be8424f27802b38e6e8d3413bf6a0b187349e68522a218f5bfc00279006ac;
        ids_[1] = 0x3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0;
        ids_[2] = 0x692c8624d30a327340b0dfbb67203e941175ac700d1a058c717e5269103d37e6;
        ids_[3] = 0xd1f43acede51c4eb2f66b86cce52682edad80b810b9d87fba3a9b67254c91b77;
        ids_[4] = 0xfda8bb1fc9938700c25353c0a5fabc96a238e69ce8e35f08e558831a20db33a6;
    }

    function _sgxRethMrEnclavesToDisable() private pure returns (bytes32[] memory ids_) {
        ids_ = new bytes32[](26);
        ids_[0] = 0x13ea9869632ac20b176ae0fdc39998b2a644a695db024ef7fe0e4b3c59084160;
        ids_[1] = 0x3551faac39edee5abfaa19ab065c217db1485aebae255a9edddf6dfff6b29b52;
        ids_[2] = 0x3b589538b775ddbfc5fb028167ff846116159e6687aef9f849ca5a70a7871ea5;
        ids_[3] = 0x3f71cf178a032816c2731a43aef746c464a5326e891dc881773ec2b599b2cf0a;
        ids_[4] = 0x482b06132c4306ea55bc34ff90d46532ff4151f473dbfe4d2cb2442af2ff288b;
        ids_[5] = 0x59bf7d48610cc8a56ba8a390b68c31a1443297869b174aeacac67dc152820f0e;
        ids_[6] = 0x605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f;
        ids_[7] = 0x631778b0d420d2d0bba4c730b0fd74857afeefb3429371ae97ab450e40ca127e;
        ids_[8] = 0x67742ab222790e20ba3656b3b294645a3384a5df5a770b86f8c06529523d990e;
        ids_[9] = 0x6e43c1d575b5b785d0f6259dfac44998c6f0c164864f9f98270fb740c14eb943;
        ids_[10] = 0x72258d3cae0e9901d0efc1f630064f1c44f11950bd25fee0b62ec8df84532da2;
        ids_[11] = 0x8f73135b83a84126c7fff37ea02f9363e134aea0f6446b13e198b20d94e75099;
        ids_[12] = 0x9546301721e2ea111ab0f79b6e529d6bb6c486ac98bcf7739429ad06c09db63d;
        ids_[13] = 0xa096348d480eb0474f5eab182671933c029545521960d87d4e49283005809be9;
        ids_[14] = 0xa4eedfc6484494d4c08bfb9b9dd887c6e0540ba9d8ee207fe0e16814852e3356;
        ids_[15] = 0xa5f741bfed254a1e21738d429e7bd074e25918af7f71fbe1e0135c3974b06e00;
        ids_[16] = 0xb09f9005e4612526e378466b5c16ab6028478e81c085812d6ed37166c4cda10e;
        ids_[17] = 0xbdec26abd36fde2cfbb8db7a0793a9346b11bd558b39890407d458500711c88c;
        ids_[18] = 0xc90e5d2e39d1d3f8397a6048c32ba50139d1577c28985e1f7638785935f41734;
        ids_[19] = 0xca349ba0dfeced0bd837a56c97417c11e51d490eec4ff08321dd130776a413bd;
        ids_[20] = 0xdcd483d3406d9b1871bb92420f5a080c4372e0d6b8522a4a2cb91a0f736669c6;
        ids_[21] = 0xddda8ba9c9153e3d2f680f2f53adbc774a9753cc55d40dde4cb02aef38c42109;
        ids_[22] = 0xdfcb4fca3073e3f3a90b05d328688c32619d56f26789c0a9797aa10e765a7807;
        ids_[23] = 0xe2375b778ee5700a73c7fcf449abb4a62e00127d324b6694898073ba5aff4f5c;
        ids_[24] = 0xe5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a;
        ids_[25] = 0xf285b7cbd78d2b96cdc54cfea3e47d8f510a4b4f91b719c97f8bbb90974f805b;
    }
}

contract Proposal0017Harness is Proposal0017 {
    function exposedBuildL1Actions() external pure returns (Controller.Action[] memory actions_) {
        actions_ = buildL1Actions();
    }

    function exposedBuildL1Actions(
        address _mainnetInboxNewImpl,
        address _signalServiceNewImpl,
        address _mainnetBridgeNewImpl,
        address _mainnetErc20VaultNewImpl
    )
        external
        pure
        returns (Controller.Action[] memory actions_)
    {
        actions_ = buildL1Actions(
            _mainnetInboxNewImpl,
            _signalServiceNewImpl,
            _mainnetBridgeNewImpl,
            _mainnetErc20VaultNewImpl
        );
    }
}

interface IBridgeRecovery {
    function init3(bytes32[] calldata _msgHashes) external;
}

interface IInboxRecovery {
    function init2(
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedBlockHash
    )
        external;
}

interface IAutomataAttestationRecovery {
    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external;
    function setMrSigner(bytes32 _mrSigner, bool _trusted) external;
}
