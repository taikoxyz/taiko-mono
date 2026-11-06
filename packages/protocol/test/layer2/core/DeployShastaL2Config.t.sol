// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DeployShastaL2Contracts } from "script/layer2/DeployShastaL2Contracts.s.sol";
import { DeployShastaL2Hoodi } from "script/layer2/DeployShastaL2Hoodi.s.sol";
import { DeployShastaL2Mainnet } from "script/layer2/DeployShastaL2Mainnet.s.sol";
import { Anchor } from "src/layer2/core/Anchor.sol";
import { LibL2HoodiAddrs } from "src/layer2/hoodi/LibL2HoodiAddrs.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { SignalServiceL2 } from "src/shared/signal/SignalServiceL2.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import { LegacySignalService } from "test/shared/signal/LegacySignalService.sol";

interface IDeploymentConfigLoader {
    function loadConfig() external view returns (DeployShastaL2Contracts.DeploymentConfig memory);
}

contract MainnetConfigLoader is DeployShastaL2Mainnet {
    function loadConfig() external view returns (DeploymentConfig memory) {
        return _loadConfig();
    }

    function validateConfig(DeploymentConfig memory _config) external view {
        _validateConfig(_config);
    }

    function deploy(DeploymentConfig memory _config) external returns (address, address) {
        return _deploy(_config);
    }
}

contract HoodiConfigLoader is DeployShastaL2Hoodi {
    function loadConfig() external view returns (DeploymentConfig memory) {
        return _loadConfig();
    }
}

contract TestDeployShastaL2Config is CommonTest {
    uint64 private constant _ETNA_TIMESTAMP = 1_800_000_000;

    // Run all environment changes in one test so parallel tests never race vm.setEnv.
    function test_loadConfig_PreservesPauserAndRejectsMissingVersionedPauser() external {
        vm.setEnv("ETNA_TIMESTAMP", vm.toString(uint256(_ETNA_TIMESTAMP)));
        IDeploymentConfigLoader mainnet =
            IDeploymentConfigLoader(address(new MainnetConfigLoader()));
        IDeploymentConfigLoader hoodi = IDeploymentConfigLoader(address(new HoodiConfigLoader()));

        _checkLoader(mainnet, LibL2Addrs.SIGNAL_SERVICE);
        _checkLoader(hoodi, LibL2HoodiAddrs.HOODI_SIGNAL_SERVICE);
        assertEq(mainnet.loadConfig().l2ChainId, LibNetwork.TAIKO_MAINNET, "mainnet L2");
        assertEq(hoodi.loadConfig().l2ChainId, LibNetwork.TAIKO_HOODI, "Hoodi L2");
    }

    function test_validateConfig_RequiresAFutureUint48EtnaTimestamp() external {
        MainnetConfigLoader loader = new MainnetConfigLoader();
        DeployShastaL2Contracts.DeploymentConfig memory config = _liveConfig();
        config.etnaTimestamp = type(uint48).max;
        loader.validateConfig(config);

        config.etnaTimestamp = uint64(type(uint48).max) + 1;
        vm.expectRevert(bytes("ETNA_TIMESTAMP above 2^48 - 1"));
        loader.validateConfig(config);

        config.etnaTimestamp = uint64(block.timestamp);
        vm.expectRevert(bytes("ETNA_TIMESTAMP not in the future"));
        loader.validateConfig(config);
    }

    /// @dev The script runs only on its own L2, against proxies with code, and only when the live
    /// Anchor already saves into the configured SignalService for the configured L1. Otherwise a
    /// run on the wrong network deploys an Anchor whose checkpoint store has no code.
    function test_validateConfig_RejectsWrongNetworkAndWiring() external {
        MainnetConfigLoader loader = new MainnetConfigLoader();
        DeployShastaL2Contracts.DeploymentConfig memory config = _liveConfig();
        loader.validateConfig(config);

        config.l2ChainId = LibNetwork.TAIKO_MAINNET;
        vm.expectRevert(bytes("Wrong L2 chain"));
        loader.validateConfig(config);

        config = _liveConfig();
        config.l2SignalService = makeAddr("codeless");
        vm.expectRevert(bytes("L2_SIGNAL_SERVICE has no code"));
        loader.validateConfig(config);

        config = _liveConfig();
        config.anchorProxy = makeAddr("codeless");
        vm.expectRevert(bytes("ANCHOR_PROXY has no code"));
        loader.validateConfig(config);

        // The live Anchor saves into another SignalService.
        config = _liveConfig();
        config.l2SignalService = address(new Anchor(ICheckpointStore(address(1)), 1, 1));
        vm.expectRevert(bytes("ANCHOR_PROXY checkpoint store mismatch"));
        loader.validateConfig(config);

        // The live Anchor trusts another L1.
        config = _liveConfig();
        config.l1ChainId = uint64(LibNetwork.ETHEREUM_HOODI);
        vm.expectRevert(bytes("ANCHOR_PROXY L1 chain id mismatch"));
        loader.validateConfig(config);

        // A proxy whose implementation has neither getter.
        config = _liveConfig();
        vm.etch(config.anchorProxy, hex"5f5ff3");
        vm.expectRevert(bytes("Live getter unreadable"));
        loader.validateConfig(config);
    }

    /// @dev The Anchor saves checkpoints into the L2 SignalService proxy, and SignalServiceL2
    /// accepts them only from the Anchor proxy and proves against the L1 SignalService. Swapping
    /// the first two would make every Unzen `anchorV4` revert once the DAO batch installs both
    /// implementations; a wrong remote would make every L1 to L2 proof fail.
    function test_deploy_WiresAnchorAndSignalServiceL2() external {
        MainnetConfigLoader loader = new MainnetConfigLoader();
        DeployShastaL2Contracts.DeploymentConfig memory config =
            DeployShastaL2Contracts.DeploymentConfig({
                l1ChainId: 1,
                l1SignalService: makeAddr("l1SignalService"),
                l2SignalService: makeAddr("l2SignalService"),
                anchorProxy: makeAddr("anchorProxy"),
                signalServicePauser: Alice,
                etnaTimestamp: _ETNA_TIMESTAMP,
                l2ChainId: uint64(block.chainid)
            });
        (address anchorImpl, address signalServiceImpl) = loader.deploy(config);

        Anchor anchor = Anchor(anchorImpl);
        assertEq(address(anchor.checkpointStore()), config.l2SignalService, "checkpoint store");
        assertEq(anchor.l1ChainId(), config.l1ChainId, "L1 chain id");
        assertEq(anchor.etnaTimestamp(), config.etnaTimestamp, "Etna timestamp");

        SignalServiceL2 signalService = SignalServiceL2(signalServiceImpl);
        assertEq(signalService.pauser(), Alice, "pauser");
        // The remote has no getter; the runtime embeds it as an immutable word.
        assertTrue(_embeds(signalServiceImpl.code, config.l1SignalService), "remote");
        assertFalse(_embeds(signalServiceImpl.code, config.l2SignalService), "not the L2 one");
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 1, blockHash: bytes32(uint256(1)), stateRoot: bytes32(uint256(2))
        });
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        vm.prank(config.l2SignalService);
        signalService.saveCheckpoint(checkpoint);
        vm.prank(config.anchorProxy);
        signalService.saveCheckpoint(checkpoint);
        assertEq(signalService.getCheckpoint(1).stateRoot, checkpoint.stateRoot, "saved");
    }

    /// @dev A valid configuration on this chain: a SignalService with code and a live Anchor that
    /// saves into it for L1 chain 1.
    function _liveConfig()
        private
        returns (DeployShastaL2Contracts.DeploymentConfig memory config_)
    {
        address l2SignalService = makeAddr("l2SignalService");
        vm.etch(l2SignalService, hex"00");
        Anchor liveAnchor = new Anchor(ICheckpointStore(l2SignalService), 1, _ETNA_TIMESTAMP);
        config_ = DeployShastaL2Contracts.DeploymentConfig({
            l1ChainId: 1,
            l1SignalService: makeAddr("l1SignalService"),
            l2SignalService: l2SignalService,
            anchorProxy: address(liveAnchor),
            signalServicePauser: address(0),
            etnaTimestamp: _ETNA_TIMESTAMP,
            l2ChainId: uint64(block.chainid)
        });
    }

    /// @dev Whether `_code` contains `_value` as a left-padded 32-byte word, the form an immutable
    /// address takes in a runtime.
    function _embeds(bytes memory _code, address _value) private pure returns (bool) {
        bytes32 target = bytes32(uint256(uint160(_value)));
        for (uint256 i; i + 32 <= _code.length; ++i) {
            bytes32 word;
            assembly {
                word := mload(add(add(_code, 0x20), i))
            }
            if (word == target) return true;
        }
        return false;
    }

    function _checkLoader(IDeploymentConfigLoader _loader, address _signalService) private {
        // An address without code would answer every getter with nothing, which reads as zero.
        vm.etch(_signalService, "");
        _expectLoaderRevert(_loader);

        SignalService implementation = new SignalService(address(this), address(1), Alice);
        vm.etch(_signalService, address(implementation).code);
        _expectPauser(_loader, _signalService, Alice);

        // A versioned implementation must expose its immutable pauser, even when it is zero.
        implementation = new SignalService(address(this), address(1), address(0));
        vm.etch(_signalService, address(implementation).code);
        _expectPauser(_loader, _signalService, address(0));
        vm.mockCall(_signalService, abi.encodeWithSignature("pauser()"), "");
        _expectLoaderRevert(_loader);
        vm.clearMockedCalls();
        vm.mockCallRevert(_signalService, abi.encodeWithSignature("pauser()"), "");
        _expectLoaderRevert(_loader);
        vm.clearMockedCalls();

        // The genuine historical implementation has neither pauser nor VERSION getters.
        LegacySignalService legacy = new LegacySignalService(address(this), address(1));
        vm.etch(_signalService, address(legacy).code);
        _expectPauser(_loader, _signalService, address(0));

        // Unknown selectors may return empty bytes successfully or revert without data.
        vm.etch(_signalService, hex"5f5ff3");
        _expectPauser(_loader, _signalService, address(0));
        vm.etch(_signalService, hex"5f5ffd");
        _expectPauser(_loader, _signalService, address(0));

        // With no pauser data, any nonempty VERSION response must fail, including bad ABI.
        vm.etch(_signalService, hex"5f5ff3");
        vm.mockCall(_signalService, abi.encodeWithSignature("VERSION()"), abi.encode(uint256(1)));
        _expectLoaderRevert(_loader);
        vm.clearMockedCalls();
        vm.mockCall(_signalService, abi.encodeWithSignature("VERSION()"), hex"01");
        _expectLoaderRevert(_loader);
        vm.clearMockedCalls();
        vm.mockCall(_signalService, abi.encodeWithSignature("VERSION()"), new bytes(33));
        _expectLoaderRevert(_loader);
        vm.clearMockedCalls();
        vm.mockCallRevert(_signalService, abi.encodeWithSignature("VERSION()"), hex"01");
        _expectLoaderRevert(_loader);
        vm.clearMockedCalls();

        // Nonempty malformed or reverting pauser responses cannot erase pause authority.
        vm.etch(_signalService, hex"6001600052601f6000f3");
        _expectLoaderRevert(_loader);
        vm.etch(_signalService, hex"600160005260216000f3");
        _expectLoaderRevert(_loader);
        vm.etch(_signalService, hex"600160005260206000fd");
        _expectLoaderRevert(_loader);
        vm.etch(_signalService, hex"5f5ff3");
        vm.mockCall(
            _signalService, abi.encodeWithSignature("pauser()"), abi.encode(uint256(1) << 160)
        );
        _expectLoaderRevert(_loader);
        vm.clearMockedCalls();
    }

    function _expectPauser(
        IDeploymentConfigLoader _loader,
        address _signalService,
        address _pauser
    )
        private
        view
    {
        DeployShastaL2Contracts.DeploymentConfig memory config = _loader.loadConfig();
        assertEq(config.signalServicePauser, _pauser, "existing pauser was not preserved");
        assertEq(config.l2SignalService, _signalService);
        assertEq(config.etnaTimestamp, _ETNA_TIMESTAMP);
    }

    function _expectLoaderRevert(IDeploymentConfigLoader _loader) private {
        vm.expectRevert();
        _loader.loadConfig();
    }
}
