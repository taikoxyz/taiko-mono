// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PreconfSlasherBase.sol";
import "src/shared/common/EssentialContract.sol";

contract TestPreconfSlasher_Common is PreconfSlasherBase {
    using LibBlockHeader for LibBlockHeader.BlockHeader;

    function test_revertsWhenSenderIsNotUrc() external {
        ISlasher.Delegation memory delegation;
        ISlasher.Commitment memory commitment;

        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        preconfSlasher.slash(delegation, commitment, address(0), hex"", address(0));
    }

    function test_revertsWhenCommitterIsFallbackPreconfer() external transactBy(urc) {
        ISlasher.Delegation memory delegation;
        ISlasher.Commitment memory commitment;

        vm.expectRevert(IPreconfSlasher.FallBackPreconferCannotBeSlashed.selector);
        preconfSlasher.slash(delegation, commitment, fallbackPreconfer, hex"", address(0));
    }

    function test_revertsWhenDomainSeparatorIsInvalid() external transactBy(urc) {
        ISlasher.Delegation memory delegation;
        IPreconfSlasher.CommitmentPayload memory commitmentPayload;

        commitmentPayload.domainSeparator = bytes32(0);
        commitmentPayload.chainId = LibNetwork.TAIKO_MAINNET;

        ISlasher.Commitment memory commitment;
        commitment.payload = abi.encode(commitmentPayload);

        vm.expectRevert(IPreconfSlasher.InvalidDomainSeparator.selector);
        preconfSlasher.slash(delegation, commitment, address(0), hex"", address(0));
    }

    function test_revertsWhenChainIdIsInvalid() external transactBy(urc) {
        ISlasher.Delegation memory delegation;
        IPreconfSlasher.CommitmentPayload memory commitmentPayload;

        commitmentPayload.domainSeparator = LibPreconfConstants.PRECONF_DOMAIN_SEPARATOR;
        commitmentPayload.chainId = 0;

        ISlasher.Commitment memory commitment;
        commitment.payload = abi.encode(commitmentPayload);

        vm.expectRevert(IPreconfSlasher.InvalidChainId.selector);
        preconfSlasher.slash(delegation, commitment, address(0), hex"", address(0));
    }

    function test_revertsWhenViolationTypeIsInvalid() external transactBy(urc) {
        ISlasher.Delegation memory delegation;
        IPreconfSlasher.CommitmentPayload memory commitmentPayload;

        commitmentPayload.domainSeparator = LibPreconfConstants.PRECONF_DOMAIN_SEPARATOR;
        commitmentPayload.chainId = LibNetwork.TAIKO_MAINNET;

        ISlasher.Commitment memory commitment;
        commitment.payload = abi.encode(commitmentPayload);

        vm.expectRevert();
        preconfSlasher.slash(
            delegation,
            commitment,
            address(0),
            bytes.concat(
                bytes1(uint8(10)), // Invalid violation type
                hex""
            ),
            address(0)
        );
    }
}
