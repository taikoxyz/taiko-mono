// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaRegistryCasesBase } from "./EtnaRegistryCasesBase.sol";

/// @notice Two ordinary exit/withdrawal cycles through the pinned Registry proxy.
contract EtnaRegistryLifecycleCasesTest is EtnaRegistryCasesBase {
    bytes private _journal;
    address[3] private _lifetimeSigners;

    function test_exit_withdraw_and_reuse() external {
        _setupRegistry(0);
        _fund(OWNER_A, 8, 8);
        _fund(OWNER_B, 8, 8);
        for (uint256 i; i < 3; ++i) _lifetimeSigners[i] = _publicPoP(2 * i).signer;

        _registrationStep("register_first", 0, abi.encode(uint256(0)));
        _registrationStep("register_survivor", 3, abi.encode(uint256(1)));
        VM.roll(12);
        _action("topup_first", OWNER_A, abi.encodeCall(IEtnaStakingRegistry.topUp, (0, 4)));

        VM.roll(13);
        bytes memory firstExit = abi.encodeCall(IEtnaStakingRegistry.requestExit, (0));
        _refuse("exit_other_owner", OWNER_B, firstExit, IEtnaStakingRegistry.NotBondOwner.selector);
        _action("exit_first", OWNER_A, firstExit);

        VM.roll(14);
        _refuse(
            "activate_mature_exiting",
            REPORTER,
            abi.encodeCall(IEtnaStakingRegistry.activateTopUp, (0)),
            IEtnaStakingRegistry.ExitAlreadySet.selector
        );
        VM.roll(15);
        _refuse("exit_repeat", OWNER_A, firstExit, IEtnaStakingRegistry.ExitAlreadySet.selector);

        VM.roll(16);
        bytes memory firstConfirmation = abi.encodeCall(IEtnaStakingRegistry.confirmExit, (0));
        inbox.setSnapshot(14);
        _refuse("confirm_uncovered", REPORTER, firstConfirmation, IEtnaStakingRegistry.ExitNotCovered.selector);
        inbox.setSnapshot(15);
        _action("confirm_exact", REPORTER, firstConfirmation);

        VM.roll(17);
        bytes memory firstWithdrawal = abi.encodeCall(IEtnaStakingRegistry.withdraw, (0, PAYEE));
        _refuse("withdraw_early", OWNER_A, firstWithdrawal, IEtnaStakingRegistry.WithdrawalNotReady.selector);
        VM.roll(18);
        _action("withdraw_first", OWNER_A, firstWithdrawal);

        VM.roll(20);
        PublicPoP memory retired = _publicPoP(1);
        _refuse(
            "retired_key_other_owner",
            retired.owner,
            abi.encodeCall(IEtnaStakingRegistry.register, (retired.key, 4, retired.signature)),
            IEtnaStakingRegistry.KeyAlreadyUsed.selector
        );
        _registrationStep("reuse_slot", 5, abi.encode(uint256(2)));

        VM.roll(23);
        _action("exit_reused", OWNER_B, abi.encodeCall(IEtnaStakingRegistry.requestExit, (2)));
        VM.roll(26);
        inbox.setSnapshot(25);
        _action("confirm_reused", REPORTER, abi.encodeCall(IEtnaStakingRegistry.confirmExit, (2)));
        VM.roll(28);
        _action("withdraw_reused", OWNER_B, abi.encodeCall(IEtnaStakingRegistry.withdraw, (2, PAYEE)));

        emit RegistryCaseReceipt(_journal);
    }

    function _registrationStep(bytes32 _name, uint256 _row, bytes memory _return) private {
        PublicPoP memory pop = _publicPoP(_row);
        _step(
            _name, pop.owner, abi.encodeCall(IEtnaStakingRegistry.register, (pop.key, 4, pop.signature)),
            true, _return
        );
    }

    function _action(bytes32 _name, address _actor, bytes memory _call) private {
        _step(_name, _actor, _call, true, "");
    }

    function _refuse(bytes32 _name, address _actor, bytes memory _call, bytes4 _error) private {
        _step(_name, _actor, _call, false, abi.encodePacked(_error));
    }

    function _step(
        bytes32 _name,
        address _actor,
        bytes memory _data,
        bool _ok,
        bytes memory _return
    )
        private
    {
        bytes32 beforeState = _selectedState();
        bytes32 beforeRollback;
        if (!_ok) beforeRollback = _stateDigest();

        // getBlockNumber reads the EVM height after roll even when the compiler hoists block.number.
        uint256 height = VM.getBlockNumber();
        uint48 snapshot = inbox.activeCommitteeSnapshot();
        CallResult memory result = _callRegistry(_actor, _data);
        (address proxy, bytes memory callData) = _registryFrame(result, _actor, _data);
        require(height == VM.getBlockNumber() && snapshot == inbox.activeCommitteeSnapshot(), "N03 context changed");

        if (_ok) {
            require(result.ok && keccak256(result.data) == keccak256(_return), "N03 action: exact success");
        } else {
            if (_name == "activate_mature_exiting") {
                require(!result.ok, "N03 activate_mature_exiting: expected ExitAlreadySet, got success");
            }
            _requireRefusal(result, _return, beforeRollback, _stateDigest(), new bytes32[](0));
        }

        bytes memory step = abi.encode(
            _name, height, snapshot, _actor, proxy, result.ok, beforeState, _selectedState(),
            result.logs.length, callData, result.data
        );
        _journal = bytes.concat(_journal, abi.encodePacked(step.length), step);
    }

    /// @dev Hash a fixed ordered layout of independently pinned raw words and the current getter root.
    /// The six checkpoint positions remain in every observation, including after slot reuse.
    function _selectedState() private view returns (bytes32) {
        bytes32[75] memory words;
        words[0] = _raw(R);
        words[1] = _raw(R + 1);
        words[2] = _raw(R + 7);
        words[3] = registry.entriesRoot();
        require(
            registry.checkpointCount() == uint256(words[0]) && registry.entryCount() == uint256(words[1])
                && registry.bondCount() == uint256(words[2]),
            "N03 counts: raw and ABI"
        );

        uint256 checkpointBase = uint256(keccak256(abi.encode(R)));
        for (uint256 i; i < 6; ++i) {
            uint256 fields = uint256(_raw(checkpointBase + 2 * i));
            bytes32 root = _raw(checkpointBase + 2 * i + 1);
            words[4 + 2 * i] = bytes32(fields);
            words[5 + 2 * i] = root;
            if (i < uint256(words[0])) _requireCheckpoint(i, uint48(fields), uint48(fields >> 48), root);
        }
        uint256 entryBase = uint256(keccak256(abi.encode(R + 1)));
        for (uint256 i; i < 6; ++i) words[16 + i] = _raw(entryBase + i);
        words[22] = _rawMap(R + 2, 0);
        words[23] = _rawMap(R + 2, 1);
        words[24] = _rawMap(R + 2, 1 << 32);
        for (uint256 slot; slot < 2; ++slot) {
            uint256 occupant = uint256(_rawMap(R + 5, slot));
            words[25 + slot] = bytes32(occupant);
            (bool occupied, uint256 bond) = registry.bondInSlot(slot);
            require(occupied ? occupant == bond + 1 : occupant == 0 && bond == 0, "N03 slot: raw and ABI");
        }
        for (uint256 i; i < 13; ++i) words[27 + i] = _rawMap(R + 3, 1 << i);
        words[40] = _rawMap(R + 3, 4097);

        for (uint256 i; i < 3; ++i) {
            uint256 dest = 41 + 9 * i;
            uint256 bondBase = _mapSlot(R + 6, i);
            for (uint256 j; j < 4; ++j) words[dest + j] = _raw(bondBase + j);
            words[dest + 4] = _rawMap(OWNERS, i);
            words[dest + 5] = _rawMap(CONFIRM, i);
            words[dest + 6] = _rawMap(TOP, i);
            words[dest + 7] = _raw(_mapSlot(TOP, i) + 1);
            address signer = _lifetimeSigners[i];
            uint256 lifetime = uint256(_rawMap(R + 4, uint160(signer)));
            words[dest + 8] = bytes32(lifetime);
            (bool known, uint256 issued) = registry.bondForKey(signer);
            require(known ? lifetime == issued + 1 : lifetime == 0 && issued == 0, "N03 key: raw and ABI");
            (bool held, uint256 slot) = registry.slotOfBond(i);
            uint256 flags = uint256(words[dest + 3]);
            require(
                held == (uint8(flags >> 16) == 1) && slot == (held ? uint16(flags) : 0),
                "N03 bond slot: raw and ABI"
            );
        }

        words[68] = bytes32(_balance(OWNER_A));
        words[69] = bytes32(_balance(OWNER_B));
        words[70] = bytes32(_balance(PAYEE));
        words[71] = bytes32(_balance(REGISTRY));
        words[72] = bytes32(_allowance(OWNER_A));
        words[73] = bytes32(_allowance(OWNER_B));
        words[74] = bytes32(_transfers());
        return keccak256(abi.encode(words));
    }
}
