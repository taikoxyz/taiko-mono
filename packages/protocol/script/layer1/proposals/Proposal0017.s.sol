// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";

// To print the proposal action data after replacing placeholders: `P=0017 pnpm proposal`
// To dryrun the proposal on L1 after replacing placeholders: `P=0017 pnpm proposal:dryrun:l1`
contract Proposal0017 is BuildProposal {
    address private constant _MAINNET_INBOX_NEW_IMPL_PLACEHOLDER =
        0x1111111111111111111111111111111111111111;
    address private constant _SIGNAL_SERVICE_NEW_IMPL_PLACEHOLDER =
        0x2222222222222222222222222222222222222222;
    address private constant _MAINNET_BRIDGE_NEW_IMPL_PLACEHOLDER =
        0x3333333333333333333333333333333333333333;
    address private constant _MAINNET_VERIFIER_PLACEHOLDER =
        0x4444444444444444444444444444444444444444;
    address private constant _NEW_SGXGETH_VERIFIER_PLACEHOLDER =
        0x5555555555555555555555555555555555555555;
    address private constant _NEW_SGXRETH_VERIFIER_PLACEHOLDER =
        0x6666666666666666666666666666666666666666;

    // PLACEHOLDER: replace these with the deployment outputs before generating calldata.
    address public constant MAINNET_INBOX_NEW_IMPL = _MAINNET_INBOX_NEW_IMPL_PLACEHOLDER;
    address public constant SIGNAL_SERVICE_NEW_IMPL = _SIGNAL_SERVICE_NEW_IMPL_PLACEHOLDER;
    address public constant MAINNET_BRIDGE_NEW_IMPL = _MAINNET_BRIDGE_NEW_IMPL_PLACEHOLDER;

    // PLACEHOLDER: the new MainnetInbox implementation must be deployed with this verifier.
    // This address is not calldata because Inbox stores the proof verifier as an immutable.
    address public constant MAINNET_VERIFIER = _MAINNET_VERIFIER_PLACEHOLDER;
    // PLACEHOLDER: the new MainnetVerifier must be deployed with these SGX verifier contracts.
    address public constant NEW_SGXGETH_VERIFIER = _NEW_SGXGETH_VERIFIER_PLACEHOLDER;
    address public constant NEW_SGXRETH_VERIFIER = _NEW_SGXRETH_VERIFIER_PLACEHOLDER;

    address public constant RISC0_RETH_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address public constant SP1_RETH_VERIFIER = 0x96337327648dcFA22b014009cf10A2D5E2F305f6;
    address public constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;
    address public constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;

    bytes32 public constant NEW_MR_SIGNER =
        0xe08aef23d4357d47e5ac5f278ba5492a5f5fb145c4fc026995367210f21a333c;
    bytes32 public constant OLD_MR_SIGNER =
        0xca0583a715534a8c981b914589a7f0dc5d60959d9ae79fb5353299a4231673d5;

    // State at L1 block 25,367,937, one block before the first forged proof tx.
    uint48 public constant RECOVERY_NEXT_PROPOSAL_ID = 18_059;
    uint48 public constant RECOVERY_LAST_PROPOSAL_BLOCK_ID = 25_367_925;
    uint48 public constant RECOVERY_LAST_FINALIZED_PROPOSAL_ID = 18_051;
    bytes32 public constant RECOVERY_LAST_FINALIZED_BLOCK_HASH =
        0x64c2ada556b6862d2c8796e0f709c454fede9d03908711a9f04d9f9f9dcce470;

    bytes32 public constant RETRIABLE_ETH_MESSAGE_HASH =
        0x997216448ef88e6398e82b0f003abb8637d25441ca6d22b09a65f63ef077480a;
    bytes32 public constant RETRIABLE_TAIKO_MESSAGE_HASH =
        0xf2994252987db0f55b6accdf1ff979bc508cd4acfcc229ad64b23a67f6fd984d;
    bytes32 public constant RETRIABLE_TAIKO_RETRY_MESSAGE_HASH =
        0xea26be1009e743aec78e1f566e91db0b9fda29e16fec1e72e2d74c6983a68e70;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        if (
            MAINNET_INBOX_NEW_IMPL == _MAINNET_INBOX_NEW_IMPL_PLACEHOLDER
                || SIGNAL_SERVICE_NEW_IMPL == _SIGNAL_SERVICE_NEW_IMPL_PLACEHOLDER
                || MAINNET_BRIDGE_NEW_IMPL == _MAINNET_BRIDGE_NEW_IMPL_PLACEHOLDER
                || MAINNET_VERIFIER == _MAINNET_VERIFIER_PLACEHOLDER
                || NEW_SGXGETH_VERIFIER == _NEW_SGXGETH_VERIFIER_PLACEHOLDER
                || NEW_SGXRETH_VERIFIER == _NEW_SGXRETH_VERIFIER_PLACEHOLDER
        ) {
            revert PlaceholderImplementationAddress();
        }

        actions = buildL1Actions(
            MAINNET_INBOX_NEW_IMPL, SIGNAL_SERVICE_NEW_IMPL, MAINNET_BRIDGE_NEW_IMPL
        );
    }

    function buildL1Actions(
        address _mainnetInboxNewImpl,
        address _signalServiceNewImpl,
        address _mainnetBridgeNewImpl
    )
        internal
        pure
        returns (Controller.Action[] memory actions)
    {
        bytes32[] memory risc0ImageIds = _risc0ImageIdsToDisable();
        bytes32[] memory sp1ProgramIds = _sp1ProgramIdsToDisable();
        bytes32[] memory sgxGethMrEnclaves = _sgxGethMrEnclavesToDisable();
        bytes32[] memory sgxRethMrEnclaves = _sgxRethMrEnclavesToDisable();

        actions = new Controller
            .Action[](
            9 + risc0ImageIds.length + sp1ProgramIds.length + sgxGethMrEnclaves.length
                + sgxRethMrEnclaves.length
        );

        uint256 cursor;

        // Group One: eliminate forged checkpoints and retriable messages.
        actions[cursor++] = buildUpgradeAction(L1.SIGNAL_SERVICE, _signalServiceNewImpl);
        actions[cursor++] = buildUpgradeAction(L1.BRIDGE, _mainnetBridgeNewImpl);
        actions[cursor++] = Controller.Action({
            target: L1.BRIDGE,
            value: 0,
            data: abi.encodeCall(IProposal0017BridgeRecovery.init3, (_retriableMessageHashes()))
        });

        // Group Two: restore the proving system to the last known-good pre-forgery state.
        actions[cursor++] = buildUpgradeAction(L1.INBOX, _mainnetInboxNewImpl);

        // The new Inbox implementation must already point to the new MainnetVerifier.
        // The first forged proof tx is in block 25,367,938; these values are from block 25,367,937.
        actions[cursor++] = Controller.Action({
            target: L1.INBOX,
            value: 0,
            data: abi.encodeCall(
                IProposal0017InboxRecovery.init2,
                (
                    RECOVERY_NEXT_PROPOSAL_ID,
                    RECOVERY_LAST_PROPOSAL_BLOCK_ID,
                    RECOVERY_LAST_FINALIZED_PROPOSAL_ID,
                    RECOVERY_LAST_FINALIZED_BLOCK_HASH
                )
            )
        });

        // Rotate MRSIGNER trust because the new SGX verifiers keep using these attesters.
        actions[cursor++] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(IProposal0017Attestation.setMrSigner, (NEW_MR_SIGNER, true))
        });
        actions[cursor++] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(IProposal0017Attestation.setMrSigner, (NEW_MR_SIGNER, true))
        });
        actions[cursor++] = Controller.Action({
            target: SGXGETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(IProposal0017Attestation.setMrSigner, (OLD_MR_SIGNER, false))
        });
        actions[cursor++] = Controller.Action({
            target: SGXRETH_ATTESTER,
            value: 0,
            data: abi.encodeCall(IProposal0017Attestation.setMrSigner, (OLD_MR_SIGNER, false))
        });

        // Remove all currently trusted RISC0 image IDs.
        for (uint256 i; i < risc0ImageIds.length; ++i) {
            actions[cursor++] = Controller.Action({
                target: RISC0_RETH_VERIFIER,
                value: 0,
                data: abi.encodeCall(Risc0Verifier.setImageIdTrusted, (risc0ImageIds[i], false))
            });
        }

        // Remove all currently trusted SP1 program IDs.
        for (uint256 i; i < sp1ProgramIds.length; ++i) {
            actions[cursor++] = Controller.Action({
                target: SP1_RETH_VERIFIER,
                value: 0,
                data: abi.encodeCall(SP1Verifier.setProgramTrusted, (sp1ProgramIds[i], false))
            });
        }

        // TODO: New RISC0, SP1, SGX-geth, and SGX-reth IDs are intentionally pending.

        // Disable all currently trusted SGX MRENCLAVE values on the existing attesters.
        for (uint256 i; i < sgxGethMrEnclaves.length; ++i) {
            actions[cursor++] = Controller.Action({
                target: SGXGETH_ATTESTER,
                value: 0,
                data: abi.encodeCall(
                    IProposal0017Attestation.setMrEnclave, (sgxGethMrEnclaves[i], false)
                )
            });
        }

        for (uint256 i; i < sgxRethMrEnclaves.length; ++i) {
            actions[cursor++] = Controller.Action({
                target: SGXRETH_ATTESTER,
                value: 0,
                data: abi.encodeCall(
                    IProposal0017Attestation.setMrEnclave, (sgxRethMrEnclaves[i], false)
                )
            });
        }
    }

    function _retriableMessageHashes() private pure returns (bytes32[] memory hashes_) {
        hashes_ = new bytes32[](3);

        // MessageStatusChanged(..., RETRIABLE), logIndex 4:
        // https://etherscan.io/tx/0x2f44dc1b883522a88f9b0cbbdfabf9ec33884b69dd4326600c3fab7fb2277260
        hashes_[0] = RETRIABLE_ETH_MESSAGE_HASH;

        // MessageStatusChanged(..., RETRIABLE), logIndex 6:
        // https://etherscan.io/tx/0x2f44dc1b883522a88f9b0cbbdfabf9ec33884b69dd4326600c3fab7fb2277260
        hashes_[1] = RETRIABLE_TAIKO_MESSAGE_HASH;

        // MessageStatusChanged(..., RETRIABLE), logIndex 141:
        // https://etherscan.io/tx/0xabed9edc7c63191109617757814d8151110eb60b43329f4d36f0ebf5328ee96b
        hashes_[2] = RETRIABLE_TAIKO_RETRY_MESSAGE_HASH;
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

    function _sp1ProgramIdsToDisable() private pure returns (bytes32[] memory ids_) {
        ids_ = new bytes32[](12);
        ids_[0] = 0x0002ac747570512099ca19c17f5a3b9f39697e5617a19ff2f2b2464229a50c7c;
        ids_[1] = 0x0026ff63d649779a5dbc88c3359ab83399a21fb6ef9b7ec082f77a8a465806e7;
        ids_[2] = 0x0033e2cccc3296e7def7b381a4fb96fafec64f45420b6d24686779ef6236dff1;
        ids_[3] = 0x0079682c7b5af614273de79761aaad20d1c8e1a65091388b81be836632d382f8;
        ids_[4] = 0x008e24716118be9594358d8882d93d5425f0827cf0a7a4fd0ea2fc4414debfe7;
        ids_[5] = 0x009d26a03d10b4e70eef6a339187c258a7701d6a0150524684cb46b56cf9e540;
        ids_[6] = 0x01563a3a5c1448263943382f75a3b9f34b4bf2b05e867fcb65648c8429a50c7c;
        ids_[7] = 0x137fb1eb125de6973791186659ab83394d10fdb73e6dfb0205eef514465806e7;
        ids_[8] = 0x19f166660ca5b9f75ef670344fb96faf76327a2a082db49150cef3de6236dff1;
        ids_[9] = 0x3cb4163d56bd850967bcf2ec1aaad20d0e470d324244e22e037d06cc32d382f8;
        ids_[10] = 0x471238b0462fa56506b1b1102d93d5422f8413e7429e93f41d45f88814debfe7;
        ids_[11] = 0x4e93501e442d39c35ded4672187c258a3b80eb500541491a09968d6a6cf9e540;
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

    error PlaceholderImplementationAddress();
}

interface IProposal0017BridgeRecovery {
    function init3(bytes32[] calldata _msgHashes) external;
}

interface IProposal0017InboxRecovery {
    function init2(
        uint48 _nextProposalId,
        uint48 _lastProposalBlockId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedBlockHash
    )
        external;
}

interface IProposal0017Attestation {
    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external;
    function setMrSigner(bytes32 _mrSigner, bool _trusted) external;
}
