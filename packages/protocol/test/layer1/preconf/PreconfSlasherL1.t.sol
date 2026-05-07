// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";
import { PreconfSlasherL1 } from "src/layer1/preconf/impl/PreconfSlasherL1.sol";
import { UnifiedSlasher } from "src/layer1/preconf/impl/UnifiedSlasher.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { IPreconfSlasher } from "src/shared/preconf/IPreconfSlasher.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract RecordingURC {
    uint256 public slashCalls;
    bytes32 public lastRegistrationRoot;

    function slashCommitment(
        bytes32 _registrationRoot,
        ISlasher.SignedCommitment calldata,
        bytes calldata
    )
        external
        returns (uint256)
    {
        slashCalls++;
        lastRegistrationRoot = _registrationRoot;
        return 1 ether;
    }
}

contract PreconfSlasherL1Test is CommonTest {
    bytes internal constant FAKE_PROOF = "";
    uint64 internal constant ATTACKER_CHAIN_ID = 9_999_999;

    RecordingURC internal urc;
    SignalService internal signalService;
    Bridge internal l1Bridge;
    PreconfSlasherL1 internal preconfSlasherL1;
    UnifiedSlasher internal unifiedSlasher;

    address internal preconfSlasherL2 = makeAddr("preconfSlasherL2");

    function setUpOnEthereum() internal override {
        signalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("remote signal service")))), deployer
        );
        l1Bridge = deployBridge(address(new Bridge(address(resolver), address(signalService))));
        vm.deal(address(l1Bridge), 100 ether);

        resolver.registerAddress(
            ATTACKER_CHAIN_ID, "bridge", address(uint160(uint256(keccak256("attacker bridge"))))
        );

        urc = new RecordingURC();
        preconfSlasherL1 =
            new PreconfSlasherL1(address(urc), preconfSlasherL2, taikoChainId, address(l1Bridge));
        unifiedSlasher = new UnifiedSlasher(
            address(preconfSlasherL1), makeAddr("lookaheadSlasher"), address(urc)
        );
    }

    function setUpOnTaiko() internal override {
        register("bridge", address(uint160(uint256(keccak256("taiko bridge")))));
    }

    function test_onMessageInvocation_rejectsDirectCalls() external {
        vm.expectRevert(PreconfSlasherL1.CallerIsNotBridge.selector);
        unifiedSlasher.onMessageInvocation(_slashingData(keccak256("direct")));
    }

    function test_onMessageInvocation_acceptsExpectedL2SenderAndChain() external {
        bytes32 registrationRoot = keccak256("victim operator");

        vm.prank(Alice);
        (IBridge.Status status, IBridge.StatusReason reason) =
            l1Bridge.processMessage(_message(uint64(taikoChainId), registrationRoot), FAKE_PROOF);

        assertEq(uint8(status), uint8(IBridge.Status.DONE));
        assertEq(uint8(reason), uint8(IBridge.StatusReason.INVOCATION_OK));
        assertEq(urc.slashCalls(), 1);
        assertEq(urc.lastRegistrationRoot(), registrationRoot);
    }

    function test_onMessageInvocation_rejectsWrongSourceChain() external {
        bytes32 registrationRoot = keccak256("victim operator");

        vm.prank(Alice);
        (IBridge.Status status, IBridge.StatusReason reason) =
            l1Bridge.processMessage(_message(ATTACKER_CHAIN_ID, registrationRoot), FAKE_PROOF);

        assertEq(uint8(status), uint8(IBridge.Status.RETRIABLE));
        assertEq(uint8(reason), uint8(IBridge.StatusReason.INVOCATION_FAILED));
        assertEq(urc.slashCalls(), 0);
    }

    function _message(
        uint64 _srcChainId,
        bytes32 _registrationRoot
    )
        private
        view
        returns (IBridge.Message memory)
    {
        return IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 0,
            from: preconfSlasherL2,
            srcChainId: _srcChainId,
            srcOwner: preconfSlasherL2,
            destChainId: ethereumChainId,
            destOwner: Alice,
            to: address(unifiedSlasher),
            value: 0,
            data: abi.encodeCall(
                IMessageInvocable.onMessageInvocation, (_slashingData(_registrationRoot))
            )
        });
    }

    function _slashingData(bytes32 _registrationRoot) private view returns (bytes memory) {
        return abi.encode(
            IPreconfSlasher.Fault.InvalidEOP,
            _registrationRoot,
            ISlasher.SignedCommitment({
                commitment: ISlasher.Commitment({
                    commitmentType: LibPreconfConstants.PRECONF_COMMITMENT_TYPE,
                    payload: abi.encode(_preconfirmation()),
                    slasher: address(unifiedSlasher)
                }),
                signature: hex"1234"
            })
        );
    }

    function _preconfirmation() private pure returns (IPreconfSlasher.Preconfirmation memory) {
        return IPreconfSlasher.Preconfirmation({
            eop: false,
            blockNumber: 1,
            anchorBlockNumber: 1,
            parentRawTxListHash: bytes32(0),
            rawTxListHash: bytes32(0),
            parentSubmissionWindowEnd: 1,
            submissionWindowEnd: 2
        });
    }
}
