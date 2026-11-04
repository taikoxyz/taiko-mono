// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaTestKeys } from "../EtnaTestKeys.sol";
import { MockEtnaInbox } from "../MockEtnaInbox.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test } from "forge-std/src/Test.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

/// @title EtnaCurrentRegistryConformanceTest
/// @notice Replays the current permanent-bond model's admission vectors with real keys and token
/// payments. Historical registry/recovery vectors describe a different registry and stay separate.
/// @dev Fixture key n is private key n; account n maps to 0x10000 + n, with zero unchanged.
/// The model's registration payment receipt maps to the token's caller-to-registry Transfer event.
contract EtnaCurrentRegistryConformanceTest is Test {
    string private constant _FILE = "/test/layer1/etna/conformance/vectors/registry_admission.json";
    string private constant _AUTHORITY_COMMIT = "1135c9b24fd03f50cb48eab250879435fd54f528";

    struct RegistrationCall {
        address caller;
        uint256 key;
        uint256 amount;
        bool wantRevert;
        bytes32 beforeState;
    }

    TestERC20 private _token;
    MockEtnaInbox private _inbox;
    EtnaStakingRegistry private _registry;
    bytes32 private _openingRoot;

    /// @notice Runs every current admission vector, including its paid opening transactions.
    function test_conformance_currentRegistryAdmission() external {
        vm.pauseGasMetering();
        string memory j = vm.readFile(string.concat(vm.projectRoot(), _FILE));
        assertEq(vm.parseJsonString(j, ".schema"), "etna-current-registry-admission-1");
        assertEq(vm.parseJsonString(j, ".authorityCommit"), _AUTHORITY_COMMIT);
        assertEq(
            vm.parseJsonString(j, ".model"),
            "Etna.Design.Current.RegistryPayments.executeTransaction"
        );
        assertTrue(vm.keyExistsJson(j, ".vectors[7].id"), "all eight vectors present");
        assertFalse(vm.keyExistsJson(j, ".vectors[8].id"), "unexpected current vector");
        uint256 snapshot = vm.snapshotState();
        for (uint256 i; i < 8; ++i) {
            emit log_string(vm.parseJsonString(
                    j, string.concat(".vectors[", vm.toString(i), "].id")
                ));
            this.runVector(j, i);
            vm.revertToState(snapshot);
        }
        emit log_named_uint("current registry admission vectors", 8);
    }

    /// @notice Replays one vector in a separate frame so its registration memory is released.
    /// @param _j The generated JSON document.
    /// @param _index The vector index.
    function runVector(string memory _j, uint256 _index) external {
        require(msg.sender == address(this), "self only");
        string memory p = string.concat(".vectors[", vm.toString(_index), "]");
        _setup(_j, string.concat(p, ".setup"));
        string memory c = string.concat(p, ".call");
        string memory e = string.concat(p, ".expect");
        _runCall(_j, c, e);
        _checkOpening(_j, string.concat(p, ".setup"));
    }

    /// @dev Executes the generated registration and compares its decision and atomic effects.
    /// @param _j The generated JSON document.
    /// @param _c The registration call's JSON path.
    /// @param _e The expected result's JSON path.
    function _runCall(string memory _j, string memory _c, string memory _e) private {
        assertEq(vm.parseJsonString(_j, string.concat(_c, ".fn")), "register");
        RegistrationCall memory x;
        x.caller = _account(_u(_j, _c, ".caller"));
        x.key = _u(_j, _c, ".key");
        x.amount = _u(_j, _c, ".amount");
        x.wantRevert = vm.parseJsonBool(_j, string.concat(_e, ".revert"));
        _token.mint(x.caller, 100);
        vm.prank(x.caller);
        _token.approve(address(_registry), 100);
        vm.roll(_u(_j, _c, ".block"));
        if (x.wantRevert) x.beforeState = this.stateDigest(x.caller, x.key);
        (bool ok, bytes memory ret, Vm.Log[] memory logs) = _register(x);
        assertEq(!ok, x.wantRevert, "register revert decision");
        if (x.wantRevert) {
            assertTrue(vm.parseJsonBool(_j, string.concat(_e, ".stateUnchanged")));
            assertEq(this.stateDigest(x.caller, x.key), x.beforeState, "reverted state unchanged");
            assertEq(logs.length, 0, "revert leaves no events");
            return;
        }
        uint256 bondId = _u(_j, _e, ".bondId");
        assertEq(abi.decode(ret, (uint256)), bondId, "returned permanent bond id");
        _checkSuccess(_j, _e, x, logs);
    }

    /// @dev Calls the real registry with this fixture key's valid proof of possession.
    /// @param _x The generated call and its decoded fixture identities.
    /// @return ok_ Whether the registration succeeded.
    /// @return ret_ The registration's raw return or revert data.
    /// @return logs_ The events emitted by the registration.
    function _register(RegistrationCall memory _x)
        private
        returns (bool ok_, bytes memory ret_, Vm.Log[] memory logs_)
    {
        bytes memory publicKey = EtnaTestKeys.publicKey(_x.key);
        bytes memory pop = EtnaTestKeys.popSig(_x.key, _registry, _x.caller);
        vm.recordLogs();
        vm.prank(_x.caller);
        (ok_, ret_) = address(_registry)
            .call(abi.encodeCall(IEtnaStakingRegistry.register, (publicKey, _x.amount, pop)));
        logs_ = vm.getRecordedLogs();
    }

    /// @notice Registers an opening bond in its own frame to bound memory during 4096 calls.
    /// @param _key The fixture key.
    /// @param _stake The effective principal.
    function registerOpening(uint256 _key, uint256 _stake) external {
        require(msg.sender == address(this), "self only");
        address owner = _account(7);
        _token.mint(owner, _stake);
        vm.prank(owner);
        _token.approve(address(_registry), _stake);
        bytes memory key = EtnaTestKeys.publicKey(_key);
        bytes memory pop = EtnaTestKeys.popSig(_key, _registry, owner);
        vm.prank(owner);
        assertEq(_registry.register(key, _stake, pop), _key - 1, "opening bond id");
    }

    /// @dev Deploys and materializes the opening with the public registry/token entry points.
    /// @param _j The generated JSON document.
    /// @param _p The opening setup's JSON path.
    function _setup(string memory _j, string memory _p) private {
        _token = new TestERC20("Taiko", "TAIKO");
        _inbox = new MockEtnaInbox();
        _inbox.setInitialized(true);
        _registry = EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(
                        new EtnaStakingRegistry(
                            IEtnaStakingRegistry.Config({
                                token: address(_token),
                                minStake: 1,
                                activationDelay: 1,
                                exitDelay: 1,
                                withdrawalDelay: 3,
                                slashBountyBps: 1000,
                                slashSink: _account(5),
                                l2ChainId: 167,
                                inbox: address(_inbox),
                                forfeitBps: 1000
                            })
                        )
                    ),
                    abi.encodeCall(EtnaStakingRegistry.init, (address(this)))
                )
            )
        );
        vm.roll(0);
        uint256 count = _u(_j, _p, ".slotCount");
        assertEq(count, _registry.MAX_ENTRIES(), "opening fills all slots");
        uint256 low = _u(_j, _p, ".lowIndex");
        (bool hasSecond, uint256 second) = _nullableUint(_j, string.concat(_p, ".secondLowIndex"));
        uint256 ordinary = _u(_j, _p, ".defaultStake");
        uint256 lowStake = _u(_j, _p, ".lowStake");
        for (uint256 i; i < count; ++i) {
            this.registerOpening(
                i + 1, i == low || (hasSecond && i == second) ? lowStake : ordinary
            );
        }
        _openingRoot = _registry.entriesRoot();
        uint256 pending = _u(_j, _p, ".lowPending");
        if (pending != 0) {
            vm.roll(1);
            _token.mint(_account(7), pending);
            vm.prank(_account(7));
            _token.approve(address(_registry), pending);
            vm.prank(_account(7));
            _registry.topUp(low, pending);
        }
        _inbox.setActiveCommitteeSnapshot(_u(_j, _p, ".landedSnapshot"));
        if (vm.parseJsonBool(_j, string.concat(_p, ".vacantLow"))) {
            _vacate(_j, string.concat(_p, ".vacancyLifecycle"), low);
        }
        assertEq(_registry.bondCount(), count, "opening bonds");
        assertEq(_registry.entryCount(), count, "opening slots");
        assertEq(_registry.checkpointAt(0).l1Block, 0, "retained opening checkpoint");
    }

    /// @dev Checks the paid pending deposit and retained vacancy history after registration too.
    /// @param _j The generated JSON document.
    /// @param _p The opening setup's JSON path.
    function _checkOpening(string memory _j, string memory _p) private {
        uint256 low = _u(_j, _p, ".lowIndex");
        (uint256 pending, uint48 ready) = _registry.topUpOf(low);
        assertEq(pending, _u(_j, _p, ".lowPending"), "opening pending principal retained");
        assertEq(ready, pending == 0 ? 0 : 2, "opening top-up readiness retained");
        IEtnaStakingRegistry.Checkpoint memory first = _registry.checkpointAt(0);
        assertEq(first.l1Block, 0, "retained opening block");
        assertEq(first.count, _u(_j, _p, ".slotCount"), "retained opening slot count");
        assertEq(first.entriesRoot, _openingRoot, "retained opening entries root");
        bool vacant = vm.parseJsonBool(_j, string.concat(_p, ".vacantLow"));
        assertEq(
            _token.balanceOf(_account(7)),
            vacant ? _u(_j, _p, ".lowStake") : 0,
            "opening owner payment"
        );
        if (vacant) {
            string memory lifecycle = string.concat(_p, ".vacancyLifecycle");
            assertEq(
                _registry.checkpointAt(1).l1Block,
                _u(_j, lifecycle, ".requestBlock"),
                "retained exit checkpoint"
            );
            assertEq(
                _registry.checkpointAt(2).l1Block,
                _u(_j, lifecycle, ".withdrawBlock"),
                "retained withdrawal checkpoint"
            );
            _checkBond(_j, string.concat(lifecycle, ".withdrawnBond"), low);
        }
    }

    /// @dev Creates the vacant slot by requesting/confirming exit and paying the withdrawal.
    /// @param _j The generated JSON document.
    /// @param _p The vacancy lifecycle's JSON path.
    /// @param _bondId The opening bond to withdraw.
    function _vacate(string memory _j, string memory _p, uint256 _bondId) private {
        vm.roll(_u(_j, _p, ".requestBlock"));
        vm.prank(_account(7));
        _registry.requestExit(_bondId);
        assertEq(_registry.bondAt(_bondId).entry.exitEffectiveL1, _u(_j, _p, ".exitAt"));
        vm.roll(_u(_j, _p, ".confirmBlock"));
        _registry.confirmExit(_bondId);
        vm.roll(_u(_j, _p, ".withdrawBlock"));
        address recipient = _account(_u(_j, _p, ".recipient"));
        uint256 principal = _registry.bondAt(_bondId).entry.effStake;
        uint256 beforeBalance = _token.balanceOf(recipient);
        vm.prank(_account(7));
        _registry.withdraw(_bondId, recipient);
        assertEq(_token.balanceOf(recipient), beforeBalance + principal, "actual withdrawal payout");
        _checkBond(_j, string.concat(_p, ".withdrawnBond"), _bondId);
    }

    /// @dev Compares every expected successful registration observable with the contract.
    /// @param _j The generated JSON document.
    /// @param _e The expected result's JSON path.
    /// @param _x The registration call and its decoded fixture identities.
    /// @param _logs The events emitted by the registration.
    function _checkSuccess(
        string memory _j,
        string memory _e,
        RegistrationCall memory _x,
        Vm.Log[] memory _logs
    )
        private
    {
        uint256 bondId = _u(_j, _e, ".bondId");
        {
            uint256 slot = _u(_j, _e, ".selectedSlot");
            (bool occupied, uint256 holder) = _registry.bondInSlot(slot);
            assertTrue(occupied, "selected slot occupied");
            assertEq(holder, bondId, "selected slot holder");
        }
        _checkBond(_j, string.concat(_e, ".newBond"), bondId);
        (bool displaced, uint256 oldId) = _nullableUint(_j, string.concat(_e, ".oldBondId"));
        if (displaced) _checkBond(_j, string.concat(_e, ".oldBond"), oldId);
        assertEq(_registry.bondCount(), _u(_j, _e, ".nextId"), "next permanent id");
        assertEq(_registry.entryCount(), 4096, "no slot appended");
        {
            (bool extra,) = _nullableUint(_j, string.concat(_e, ".slot4096"));
            assertFalse(extra, "model has no slot 4096");
            vm.expectRevert(IEtnaStakingRegistry.UnknownSlot.selector);
            _registry.bondInSlot(4096);
        }
        assertEq(_token.balanceOf(_x.caller), _u(_j, _e, ".callerBalance"), "caller balance");
        assertEq(_token.balanceOf(address(_registry)), _u(_j, _e, ".registryBalance"), "reserve");
        assertEq(_token.allowance(_x.caller, address(_registry)), 100 - _x.amount, "paid allowance");
        assertEq(
            _registry.checkpointAt(_registry.checkpointCount() - 1).l1Block,
            _u(_j, _e, ".latestCheckpointBlock"),
            "new checkpoint"
        );
        _checkReceipts(_logs, _x.caller, _x.amount, _u(_j, _e, ".receiptCount"), displaced);
    }

    /// @dev Maps model payment receipts to actual token transfers and checks registry events.
    /// @param _logs The events emitted by the registration.
    /// @param _caller The owner paying the new principal.
    /// @param _amount The principal transferred to the registry.
    /// @param _expected The number of payment receipts expected by the model.
    /// @param _displaced Whether the new bond displaced an occupied slot.
    function _checkReceipts(
        Vm.Log[] memory _logs,
        address _caller,
        uint256 _amount,
        uint256 _expected,
        bool _displaced
    )
        private
        view
    {
        uint256 payments;
        uint256 registrations;
        uint256 displacements;
        bytes32 transfer = keccak256("Transfer(address,address,uint256)");
        for (uint256 i; i < _logs.length; ++i) {
            Vm.Log memory eventLog = _logs[i];
            if (eventLog.emitter == address(_token) && eventLog.topics[0] == transfer) {
                assertEq(address(uint160(uint256(eventLog.topics[1]))), _caller, "payment sender");
                assertEq(
                    address(uint160(uint256(eventLog.topics[2]))),
                    address(_registry),
                    "payment recipient"
                );
                assertEq(abi.decode(eventLog.data, (uint256)), _amount, "paid principal");
                ++payments;
            }
            if (eventLog.emitter != address(_registry)) continue;
            if (eventLog.topics[0] == IEtnaStakingRegistry.Registered.selector) ++registrations;
            if (eventLog.topics[0] == IEtnaStakingRegistry.BondDisplaced.selector) ++displacements;
        }
        assertEq(payments, _expected, "payment receipts");
        assertEq(registrations, 1, "registration event");
        assertEq(displacements, _displaced ? 1 : 0, "displacement only for an occupied slot");
    }

    /// @dev Compares all model bond fields, including the permanent key and bidirectional slot map.
    /// @param _j The generated JSON document.
    /// @param _p The expected bond's JSON path.
    /// @param _id The permanent bond id.
    function _checkBond(string memory _j, string memory _p, uint256 _id) private {
        IEtnaStakingRegistry.Bond memory b = _registry.bondAt(_id);
        uint256 key = _u(_j, _p, ".key");
        Vm.Wallet memory wallet = vm.createWallet(key);
        assertEq(b.entry.ckX, bytes32(wallet.publicKeyX), "bond key X");
        assertEq(b.entry.ckPrefix, 2 + (wallet.publicKeyY & 1), "bond key prefix");
        assertEq(_registry.ownerOf(_id), _account(_u(_j, _p, ".owner")), "bond owner");
        assertEq(b.entry.effStake, _u(_j, _p, ".stake"), "effective principal");
        (uint256 pending, uint48 readyAt) = _registry.topUpOf(_id);
        assertEq(pending, _u(_j, _p, ".pending"), "pending principal");
        assertEq(b.entry.effStake + pending, _u(_j, _p, ".balance"), "total principal");
        assertEq(readyAt, _u(_j, _p, ".readyAt"), "top-up readiness");
        assertEq(b.entry.activeFromL1, _u(_j, _p, ".activeFrom"), "activation");
        assertEq(b.entry.exitEffectiveL1, _u(_j, _p, ".exitAt"), "exit");
        assertEq(b.withdrawn, vm.parseJsonBool(_j, string.concat(_p, ".released")), "released");
        (bool confirmed, uint256 confirmation) =
            _nullableUint(_j, string.concat(_p, ".confirmedAt"));
        assertEq(_registry.exitConfirmedAtL1(_id), confirmed ? confirmation : 0, "confirmation");
        (bool holds, uint256 slot) = _nullableUint(_j, string.concat(_p, ".slot"));
        assertEq(b.holdsSlot, holds, "bond holds slot");
        (bool mapped, uint256 mappedSlot) = _registry.slotOfBond(_id);
        assertEq(mapped, holds, "slot reverse map presence");
        if (holds) {
            assertEq(b.slot, slot, "bond slot");
            assertEq(mappedSlot, slot, "slot reverse map");
            assertEq(keccak256(abi.encode(_registry.entryAt(slot))), keccak256(abi.encode(b.entry)));
        }
        (bool registered, uint256 mappedId) = _registry.bondForKey(wallet.addr);
        assertTrue(registered, "lifetime key remains registered");
        assertEq(mappedId, _id, "lifetime key bond id");
    }

    /// @notice Hashes all issued bonds, slot entries/maps, checkpoints and payment state.
    /// @param _caller The fresh registration caller.
    /// @param _newKey The attempted fresh registration key.
    /// @return digest_ The complete observable opening state, in a bounded external memory frame.
    function stateDigest(
        address _caller,
        uint256 _newKey
    )
        external
        view
        returns (bytes32 digest_)
    {
        (uint256 slot, uint256 value) = _registry.admissionThreshold();
        (bool newKeyUsed, uint256 newKeyId) = _registry.bondForKey(vm.addr(_newKey));
        digest_ = keccak256(
            abi.encode(
                _registry.bondCount(),
                _registry.entryCount(),
                _registry.entriesRoot(),
                slot,
                value,
                _registry.checkpointCount(),
                newKeyUsed,
                newKeyId
            )
        );
        digest_ = keccak256(
            abi.encode(
                digest_,
                _token.balanceOf(_caller),
                _token.balanceOf(_account(7)),
                _token.balanceOf(address(_registry)),
                _token.allowance(_caller, address(_registry)),
                _token.totalSupply()
            )
        );
        for (uint256 i; i < _registry.bondCount(); ++i) {
            digest_ = keccak256(abi.encode(digest_, this.bondDigest(i)));
        }
        for (uint256 i; i < _registry.checkpointCount(); ++i) {
            digest_ = keccak256(abi.encode(digest_, _registry.checkpointAt(i)));
        }
    }

    /// @notice Hashes one opening bond and its slot in a separate frame to bound memory use.
    /// @param _id The opening bond id, equal to its slot and key minus one.
    /// @return digest_ The complete bond, payment-side metadata and slot digest.
    function bondDigest(uint256 _id) external view returns (bytes32 digest_) {
        digest_ = keccak256(
            abi.encode(
                _registry.bondAt(_id),
                _registry.ownerOf(_id),
                _registry.exitConfirmedAtL1(_id),
                _registry.entryAt(_id)
            )
        );
        {
            (uint256 pending, uint48 ready) = _registry.topUpOf(_id);
            digest_ = keccak256(abi.encode(digest_, pending, ready));
        }
        {
            (bool used, uint256 id) = _registry.bondForKey(vm.addr(_id + 1));
            digest_ = keccak256(abi.encode(digest_, used, id));
        }
        {
            (bool occupied, uint256 holder) = _registry.bondInSlot(_id);
            digest_ = keccak256(abi.encode(digest_, occupied, holder));
        }
        (bool holds, uint256 slot) = _registry.slotOfBond(_id);
        digest_ = keccak256(abi.encode(digest_, holds, slot));
    }

    /// @dev Reads a uint or the explicit null used by the generated optional fields.
    /// @param _j The generated JSON document.
    /// @param _p The optional field's JSON path.
    /// @return present_ Whether the field contains a uint rather than null.
    /// @return value_ The uint when present, otherwise zero.
    function _nullableUint(
        string memory _j,
        string memory _p
    )
        private
        view
        returns (bool present_, uint256 value_)
    {
        assertTrue(vm.keyExistsJson(_j, _p), "missing optional field");
        try vm.parseJsonUint(_j, _p) returns (uint256 value) {
            return (true, value);
        } catch {
            assertEq(vm.parseJson(_j, _p), abi.encode(bytes32(0)), "explicit JSON null");
            return (false, 0);
        }
    }

    /// @dev Reads a generated unsigned integer field.
    /// @param _j The generated JSON document.
    /// @param _p The containing object's JSON path.
    /// @param _field The field suffix, including its leading dot.
    /// @return value_ The generated unsigned integer.
    function _u(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (uint256 value_)
    {
        return vm.parseJsonUint(_j, string.concat(_p, _field));
    }

    /// @dev Maps fixture account zero to zero, and every other account to a distinct EOA.
    /// @param _id The model's account identity.
    /// @return account_ The EVM address representing that identity.
    function _account(uint256 _id) private pure returns (address account_) {
        return _id == 0 ? address(0) : address(uint160(0x10000 + _id));
    }
}
