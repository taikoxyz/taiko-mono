// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IComponentConfigV2 } from "../../../shared/slotchain/iface/IComponentConfigV2.sol";
import { IBuilderRegistryLifecycleFacetV1 } from "../iface/IBuilderRegistryLifecycleFacetV1.sol";
import { BuilderRegistryLogicV1 } from "./BuilderRegistry.sol";

/// @title Frozen builder seat-lifecycle execution facet
/// @custom:security-contact security@taiko.xyz
contract BuilderRegistrySeatLifecycleFacetV1 is
    BuilderRegistryLogicV1,
    IBuilderRegistryLifecycleFacetV1
{
    bytes32 private constant _SELECTOR_SET_HASH =
        0x92e9dd5f246684dbc6137c40eb276993130005222bc31be614359dbc1164bbf5;
    bytes32 private constant _CONFIGURATION_HASH =
        0x5844c0d5e26f8e8006907c41fcf7c121537202827fa671a15099730c1dd38d6b;

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
            1,
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

    function reserveBuilderWindowV1(
        uint64,
        uint64,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4, uint64, uint64, uint64, bytes32)
    {
        revert UnsupportedFacetSelector();
    }

    function normalizeBuilderTranchesV1(
        address,
        uint64,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4, uint64, uint8, uint64, bytes32)
    {
        revert UnsupportedFacetSelector();
    }

    function releaseBuilderTrancheV1(
        address,
        uint64,
        uint64,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4, uint64, uint64, address, uint256, uint64, bytes32)
    {
        revert UnsupportedFacetSelector();
    }

    function releaseBuilderGenerationV1(
        address,
        uint64,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4, uint64, address, uint256, uint64, bytes32)
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
