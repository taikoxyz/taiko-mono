// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IComponentConfigV2 } from "../../../shared/slotchain/iface/IComponentConfigV2.sol";
import { IBuilderRegistryLifecycleFacetV1 } from "../iface/IBuilderRegistryLifecycleFacetV1.sol";
import { BuilderRegistryLogicV1 } from "./BuilderRegistry.sol";

/// @title Frozen builder lease and reclamation execution facet
/// @custom:security-contact security@taiko.xyz
contract BuilderRegistryLeaseLifecycleFacetV1 is
    BuilderRegistryLogicV1,
    IBuilderRegistryLifecycleFacetV1
{
    bytes32 private constant _SELECTOR_SET_HASH =
        0x895e8723291f0a1f397a981815290e003eab16a87807eadc3b3bc0d805b8fb78;
    bytes32 private constant _CONFIGURATION_HASH =
        0x768f741248a8cd1b1fc84f9134261736305ad3d373ac5a5b346057a7c1b9680a;

    /// @inheritdoc IComponentConfigV2
    function componentConfigHashV2() external pure override returns (bytes32) {
        return _CONFIGURATION_HASH;
    }

    /// @inheritdoc IBuilderRegistryLifecycleFacetV1
    function builderRegistryLifecycleFacetConfigV1()
        external
        pure
        override
        returns (bytes4, uint8, uint8, bytes32, bytes32, bytes32)
    {
        return (
            _BRF1_MAGIC,
            1,
            2,
            _BUILDER_REGISTRY_STORAGE_LAYOUT_HASH,
            _SELECTOR_SET_HASH,
            _CONFIGURATION_HASH
        );
    }

    function builderRegistryConfigV1() external pure override {
        revert UnsupportedFacetSelector();
    }

    function builderRegistryTopologyHashV1() external pure override returns (bytes32) {
        revert UnsupportedFacetSelector();
    }

    function rewardClassV1(uint8)
        external
        pure
        override
        returns (bytes4, bytes32, uint8, uint256, uint256, uint256, uint256)
    {
        revert UnsupportedFacetSelector();
    }

    function admissionStateV1() external pure override returns (bytes4, uint64, bytes32) {
        revert UnsupportedFacetSelector();
    }

    function scheduleRegistryStateV1()
        external
        pure
        override
        returns (bytes4, uint8, uint8, uint64, uint64, uint256, bytes32)
    {
        revert UnsupportedFacetSelector();
    }

    function registerBuilderV1(
        uint192,
        uint64,
        uint8,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4, uint64, uint8, uint64, uint64, bytes32)
    {
        revert UnsupportedFacetSelector();
    }

    function requestBuilderExitV1(uint64)
        external
        pure
        override
        returns (bytes4, uint64, uint64, uint8)
    {
        revert UnsupportedFacetSelector();
    }

    function processBuilderMaintenanceV1(
        uint8,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4, uint8, uint8, uint64, bytes32)
    {
        revert UnsupportedFacetSelector();
    }

    function claimBuilderLeaseCreditV1(address)
        external
        pure
        override
        returns (bytes4, address, uint256)
    {
        revert UnsupportedFacetSelector();
    }

    function submitBuilderEquivocationV1(bytes calldata)
        external
        pure
        override
        returns (bytes4, uint64, uint64, address, uint256, uint256, uint64, bytes32)
    {
        revert UnsupportedFacetSelector();
    }

    error UnsupportedFacetSelector();
}
