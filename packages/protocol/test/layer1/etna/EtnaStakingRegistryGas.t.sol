// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { MockCommitteeInbox } from "./MockCommitteeInbox.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { TaikoToken } from "src/layer1/mainnet/TaikoToken.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @dev setUp and the measured test are separate calls, so storage starts cold for each
/// measurement. Uses the actual TAIKO proxy/token and the explicit Inbox settlement fixture.
abstract contract EtnaStakingRegistryGasBase is CommonTest {
    uint256 internal constant STAKE = 1000 ether;
    TaikoToken internal token;
    EtnaStakingRegistry internal registry;
    MockCommitteeInbox internal committee;

    function setUpOnEthereum() internal override {
        token = deployTaikoToken();
    }

    function setUp() public virtual override {
        super.setUp();
        registry = EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(
                        new EtnaStakingRegistry(address(token), STAKE, 0, 0, 0, 1, 1, 10_000, STAKE)
                    ),
                    abi.encodeCall(EtnaStakingRegistry.init, (address(this)))
                )
            )
        );
        committee = new MockCommitteeInbox(address(registry));
        registry.bindInbox(address(committee));
        token.approve(address(registry), type(uint256).max);
    }

    function _registerGas(string memory _label) internal {
        vm.startSnapshotGas(_label);
        registry.register(bytes32(uint256(0xdead)), STAKE, Alice);
        uint256 gasUsed = vm.stopSnapshotGas();
        emit log_named_uint(_label, gasUsed);
        assertLt(gasUsed, 3_000_000);
    }

    function _exitGas(string memory _label) internal {
        vm.startSnapshotGas(_label);
        registry.requestExit(0);
        uint256 gasUsed = vm.stopSnapshotGas();
        emit log_named_uint(_label, gasUsed);
        assertLt(gasUsed, 3_000_000);
    }

    function _activeGas(string memory _label) internal {
        vm.startSnapshotGas(_label);
        registry.activeStake();
        uint256 gasUsed = vm.stopSnapshotGas();
        emit log_named_uint(_label, gasUsed);
        assertLt(gasUsed, 350_000);
    }
}

contract EtnaStakingRegistryInitialGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(0);
    }

    function test_gas_InitialRegistrationMaximumUpdatePath() external {
        _registerGas("initial_register");
    }
}

contract EtnaStakingRegistryDistantGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(0);
        registry.register(bytes32(uint256(1)), STAKE, Alice);
        vm.roll(uint256(1) << 32);
    }

    function test_gas_DistantRegistration() external {
        _registerGas("distant_register");
    }

    function test_gas_DistantExit() external {
        _exitGas("distant_exit");
    }

    function test_gas_MaximumPrefixQuery() external {
        vm.roll(type(uint64).max - 1);
        _activeGas("maximum_prefix");
    }
}

contract EtnaStakingRegistryWithdrawalGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(0);
        registry.register(bytes32(uint256(1)), STAKE, Alice);
        vm.roll(uint256(1) << 32);
        registry.requestExit(0);
        committee.setActiveCommitteeSnapshot(uint64(block.number));
    }

    function test_gas_WithdrawalDifferentActivationAndExitPaths() external {
        vm.startSnapshotGas("withdrawal");
        registry.withdraw(0, address(this));
        uint256 gasUsed = vm.stopSnapshotGas();
        emit log_named_uint("withdrawal", gasUsed);
        assertLt(gasUsed, 1_200_000);
    }
}

contract EtnaStakingRegistryNearCapGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(0);
        vm.pauseGasMetering();
        for (uint256 i; i < 4095; ++i) {
            registry.register(bytes32(i + 1), STAKE, Alice);
        }
        vm.resumeGasMetering();
        vm.roll(5000);
    }

    function test_gas_RegistrationIntoLastSlot() external {
        _registerGas("register_at_4095");
    }

    function test_gas_ActiveQueryNearCapacity() external {
        _activeGas("active_at_4095");
    }
}

contract EtnaStakingRegistryFullCapGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(0);
        vm.pauseGasMetering();
        for (uint256 i; i < 4096; ++i) {
            registry.register(bytes32(i + 1), STAKE, Alice);
        }
        vm.resumeGasMetering();
        vm.roll(5000);
    }

    function test_gas_ExitAtFullCapacity() external {
        _exitGas("exit_at_4096");
    }
}
