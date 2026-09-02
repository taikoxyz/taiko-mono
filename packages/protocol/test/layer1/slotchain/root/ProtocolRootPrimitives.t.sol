// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    ProtocolRootComponentV1
} from "../../../../contracts/layer1/slotchain/root/ProtocolRootComponentV1.sol";
import {
    ProtocolRootCreate3ProxyV1
} from "../../../../contracts/layer1/slotchain/root/ProtocolRootCreate3ProxyV1.sol";
import {
    IProtocolRootActivationV1
} from "../../../../contracts/shared/slotchain/iface/IProtocolRootActivationV1.sol";
import { Test } from "forge-std/src/Test.sol";

contract ProtocolRootComponentHarness is ProtocolRootComponentV1 {
    constructor(
        address _factory,
        bytes32 _factoryRuntimeHash,
        bytes32 _campaignKey,
        uint8 _role
    )
        ProtocolRootComponentV1(_factory, _factoryRuntimeHash, _campaignKey, _role)
    { }

    function guardedValue() external view onlyActiveProtocolRoot returns (uint256 value_) {
        return 1;
    }
}

contract ProtocolRootFactoryHarness {
    function createProxy(
        bytes32 _campaignKey,
        uint8 _role
    )
        external
        returns (ProtocolRootCreate3ProxyV1 proxy_)
    {
        bytes32 salt = componentSalt(_campaignKey, _role);
        proxy_ = new ProtocolRootCreate3ProxyV1{ salt: salt }();
    }

    function deployComponent(
        ProtocolRootCreate3ProxyV1 _proxy,
        bytes32 _campaignKey,
        uint8 _role
    )
        external
        returns (ProtocolRootComponentHarness component_)
    {
        component_ =
            ProtocolRootComponentHarness(_proxy.deployV1(componentInitCode(_campaignKey, _role)));
    }

    function deployBytes(
        ProtocolRootCreate3ProxyV1 _proxy,
        bytes calldata _initCode
    )
        external
        returns (address component_)
    {
        return _proxy.deployV1(_initCode);
    }

    function rawProxyCall(
        address _proxy,
        bytes calldata _calldata
    )
        external
        returns (bool success_, bytes memory returndata_)
    {
        return _proxy.call(_calldata);
    }

    function activate(
        IProtocolRootActivationV1 _component,
        bytes32 _campaignKey
    )
        external
        returns (bytes4 magic_)
    {
        return _component.activateProtocolRootV1(_campaignKey);
    }

    function componentInitCode(
        bytes32 _campaignKey,
        uint8 _role
    )
        public
        view
        returns (bytes memory initCode_)
    {
        return abi.encodePacked(
            type(ProtocolRootComponentHarness).creationCode,
            abi.encode(address(this), address(this).codehash, _campaignKey, _role)
        );
    }

    function componentSalt(
        bytes32 _campaignKey,
        uint8 _role
    )
        public
        pure
        returns (bytes32 salt_)
    {
        return
            keccak256(
                abi.encodePacked("slot-chain-protocol-root-component-v1", _campaignKey, _role)
            );
    }
}

contract ProtocolRootPrimitivesTest is Test {
    bytes4 private constant _DEPLOY_SELECTOR = 0x5d5fb6bc;
    bytes4 private constant _PRA1 = 0x50524131;
    bytes4 private constant _RAA1 = 0x52414131;

    bytes32 private constant _CAMPAIGN_KEY = keccak256("root-campaign");
    uint8 private constant _ROLE = 4;

    ProtocolRootFactoryHarness private _factory;

    function setUp() public {
        _factory = new ProtocolRootFactoryHarness();
    }

    function test_deployV1_CopiesCalldataInitCodeAndUsesExactCreate3Addresses() external {
        ProtocolRootCreate3ProxyV1 proxy = _factory.createProxy(_CAMPAIGN_KEY, _ROLE);
        address expectedProxy = _expectedProxy(address(_factory), _CAMPAIGN_KEY, _ROLE);
        address expectedComponent = _nonceOneChild(expectedProxy);
        assertEq(address(proxy), expectedProxy);
        assertEq(uint256(vm.load(address(proxy), bytes32(0))), uint256(uint160(address(_factory))));
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(1)))), 0);

        bytes memory callData = abi.encodeCall(
            ProtocolRootCreate3ProxyV1.deployV1, (_factory.componentInitCode(_CAMPAIGN_KEY, _ROLE))
        );
        assertEq(bytes4(callData), _DEPLOY_SELECTOR);
        (bool success, bytes memory returndata) = _factory.rawProxyCall(address(proxy), callData);

        assertTrue(success);
        assertEq(returndata.length, 32);
        assertEq(abi.decode(returndata, (address)), expectedComponent);
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(1)))), 1);
        assertGt(expectedComponent.code.length, 0);
    }

    function test_deployV1_RevertWhen_CalldataHasGapSuffixDirtyPaddingOrEmptyTail() external {
        ProtocolRootCreate3ProxyV1 proxy = _factory.createProxy(_CAMPAIGN_KEY, _ROLE);
        bytes memory tinyInitCode = hex"60006000f3";

        _assertRawRevert(
            proxy,
            _gappedDeployCalldata(tinyInitCode),
            ProtocolRootCreate3ProxyV1.NonCanonicalInitCode.selector
        );

        bytes memory withSuffix = bytes.concat(
            abi.encodeCall(ProtocolRootCreate3ProxyV1.deployV1, (tinyInitCode)), bytes32(0)
        );
        _assertRawRevert(
            proxy, withSuffix, ProtocolRootCreate3ProxyV1.NonCanonicalInitCode.selector
        );

        bytes memory dirtyPadding =
            abi.encodeCall(ProtocolRootCreate3ProxyV1.deployV1, (tinyInitCode));
        dirtyPadding[dirtyPadding.length - 1] = 0x01;
        _assertRawRevert(
            proxy, dirtyPadding, ProtocolRootCreate3ProxyV1.NonCanonicalInitCode.selector
        );

        _assertRawRevert(
            proxy,
            abi.encodeCall(ProtocolRootCreate3ProxyV1.deployV1, (bytes(""))),
            ProtocolRootCreate3ProxyV1.NonCanonicalInitCode.selector
        );

        address component = _factory.deployBytes(proxy, tinyInitCode);
        assertEq(component, _nonceOneChild(address(proxy)));
    }

    function test_deployV1_RevertWhen_InitCodeExceedsEip3860Limit() external {
        ProtocolRootCreate3ProxyV1 proxy = _factory.createProxy(_CAMPAIGN_KEY, _ROLE);
        bytes memory oversized = new bytes(49_153);
        _assertRawRevert(
            proxy,
            abi.encodeCall(ProtocolRootCreate3ProxyV1.deployV1, (oversized)),
            ProtocolRootCreate3ProxyV1.NonCanonicalInitCode.selector
        );
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(1)))), 0);
    }

    function test_deployV1_FailedCreateRollsBackUsedFlag() external {
        ProtocolRootCreate3ProxyV1 proxy = _factory.createProxy(_CAMPAIGN_KEY, _ROLE);
        bytes memory invalidComponent = _factory.componentInitCode(bytes32(0), _ROLE);
        bytes memory callData =
            abi.encodeCall(ProtocolRootCreate3ProxyV1.deployV1, (invalidComponent));

        _assertRawRevert(
            proxy, callData, ProtocolRootCreate3ProxyV1.ComponentDeploymentFailed.selector
        );
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(1)))), 0);

        ProtocolRootComponentHarness component =
            _factory.deployComponent(proxy, _CAMPAIGN_KEY, _ROLE);
        assertEq(address(component), _nonceOneChild(address(proxy)));
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(1)))), 1);
    }

    function test_deployV1_RevertWhen_CallerIsNotFactoryOrProxyWasUsed() external {
        ProtocolRootCreate3ProxyV1 proxy = _factory.createProxy(_CAMPAIGN_KEY, _ROLE);
        bytes memory initCode = _factory.componentInitCode(_CAMPAIGN_KEY, _ROLE);

        vm.expectRevert(ProtocolRootCreate3ProxyV1.UnauthorizedFactory.selector);
        proxy.deployV1(initCode);

        _factory.deployBytes(proxy, initCode);
        vm.expectRevert(ProtocolRootCreate3ProxyV1.ProxyAlreadyUsed.selector);
        _factory.deployBytes(proxy, initCode);
    }

    function test_protocolRootActivation_IsExactAndOneShot() external {
        ProtocolRootCreate3ProxyV1 proxy = _factory.createProxy(_CAMPAIGN_KEY, _ROLE);
        ProtocolRootComponentHarness component =
            _factory.deployComponent(proxy, _CAMPAIGN_KEY, _ROLE);

        (bool success, bytes memory raw) = address(component)
            .staticcall(abi.encodeCall(IProtocolRootActivationV1.protocolRootActivationV1, ()));
        assertTrue(success);
        assertEq(raw.length, 128);
        (bytes4 magic, address factory, bytes32 key, uint8 state) =
            abi.decode(raw, (bytes4, address, bytes32, uint8));
        assertEq(magic, _PRA1);
        assertEq(factory, address(_factory));
        assertEq(key, _CAMPAIGN_KEY);
        assertEq(state, 0);

        vm.expectRevert(ProtocolRootComponentV1.ProtocolRootInactive.selector);
        component.guardedValue();

        assertEq(_factory.activate(component, _CAMPAIGN_KEY), _RAA1);
        assertEq(component.guardedValue(), 1);
        (,,, state) = component.protocolRootActivationV1();
        assertEq(state, 1);

        vm.expectRevert(ProtocolRootComponentV1.ProtocolRootAlreadyActive.selector);
        _factory.activate(component, _CAMPAIGN_KEY);
    }

    function test_activateProtocolRootV1_RevertWhen_FactoryOrCampaignIsWrong() external {
        ProtocolRootCreate3ProxyV1 proxy = _factory.createProxy(_CAMPAIGN_KEY, _ROLE);
        ProtocolRootComponentHarness component =
            _factory.deployComponent(proxy, _CAMPAIGN_KEY, _ROLE);

        vm.expectRevert(ProtocolRootComponentV1.UnauthorizedProtocolRootFactory.selector);
        component.activateProtocolRootV1(_CAMPAIGN_KEY);

        vm.expectRevert(ProtocolRootComponentV1.ProtocolRootCampaignMismatch.selector);
        _factory.activate(component, keccak256("wrong-campaign"));

        (,,, uint8 state) = component.protocolRootActivationV1();
        assertEq(state, 0);
    }

    function test_constructor_RevertWhen_RoleOrRuntimeBindingIsWrong() external {
        ProtocolRootCreate3ProxyV1 proxy = _factory.createProxy(_CAMPAIGN_KEY, _ROLE);
        bytes memory wrongRole = _factory.componentInitCode(_CAMPAIGN_KEY, 0);
        _assertRawRevert(
            proxy,
            abi.encodeCall(ProtocolRootCreate3ProxyV1.deployV1, (wrongRole)),
            ProtocolRootCreate3ProxyV1.ComponentDeploymentFailed.selector
        );

        bytes memory wrongHash = abi.encodePacked(
            type(ProtocolRootComponentHarness).creationCode,
            abi.encode(address(_factory), bytes32(uint256(1)), _CAMPAIGN_KEY, _ROLE)
        );
        _assertRawRevert(
            proxy,
            abi.encodeCall(ProtocolRootCreate3ProxyV1.deployV1, (wrongHash)),
            ProtocolRootCreate3ProxyV1.ComponentDeploymentFailed.selector
        );
        assertEq(uint256(vm.load(address(proxy), bytes32(uint256(1)))), 0);
    }

    function _assertRawRevert(
        ProtocolRootCreate3ProxyV1 _proxy,
        bytes memory _calldata,
        bytes4 _selector
    )
        private
    {
        (bool success, bytes memory returndata) = _factory.rawProxyCall(address(_proxy), _calldata);
        assertFalse(success);
        assertGe(returndata.length, 4);
        assertEq(bytes4(returndata), _selector);
    }

    function _gappedDeployCalldata(bytes memory _initCode)
        private
        pure
        returns (bytes memory calldata_)
    {
        uint256 paddedLength = (_initCode.length + 31) & ~uint256(31);
        bytes memory padded = new bytes(paddedLength);
        for (uint256 i; i < _initCode.length; ++i) {
            padded[i] = _initCode[i];
        }
        return bytes.concat(
            _DEPLOY_SELECTOR, bytes32(uint256(64)), bytes32(0), bytes32(_initCode.length), padded
        );
    }

    function _expectedProxy(
        address _factoryAddress,
        bytes32 _campaignKey,
        uint8 _role
    )
        private
        pure
        returns (address proxy_)
    {
        bytes32 salt = keccak256(
            abi.encodePacked("slot-chain-protocol-root-component-v1", _campaignKey, _role)
        );
        proxy_ = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            _factoryAddress,
                            salt,
                            keccak256(type(ProtocolRootCreate3ProxyV1).creationCode)
                        )
                    )
                )
            )
        );
    }

    function _nonceOneChild(address _proxy) private pure returns (address component_) {
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", _proxy, hex"01")))));
    }
}
