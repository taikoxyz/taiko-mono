// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DeployShastaL2Contracts } from "script/layer2/DeployShastaL2Contracts.s.sol";
import { DeployShastaL2Hoodi } from "script/layer2/DeployShastaL2Hoodi.s.sol";
import { DeployShastaL2Mainnet } from "script/layer2/DeployShastaL2Mainnet.s.sol";
import { LibL2HoodiAddrs } from "src/layer2/hoodi/LibL2HoodiAddrs.sol";
import { LibL2Addrs } from "src/layer2/mainnet/LibL2Addrs.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import { LegacySignalService } from "test/shared/signal/LegacySignalService.sol";

interface IDeploymentConfigLoader {
    function loadConfig() external view returns (DeployShastaL2Contracts.DeploymentConfig memory);
}

contract MainnetConfigLoader is DeployShastaL2Mainnet {
    function loadConfig() external view returns (DeploymentConfig memory) {
        return _loadConfig();
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
    }

    function _checkLoader(IDeploymentConfigLoader _loader, address _signalService) private {
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
