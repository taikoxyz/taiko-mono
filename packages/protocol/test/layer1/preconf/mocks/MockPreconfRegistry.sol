// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/IPreconfRegistry.sol";

contract MockPreconfRegistry {
    mapping(address preconfer => uint256 index) internal preconferToIndex;
    mapping(uint256 index => address preconfer) internal indexToPreconfer;
    mapping(bytes32 pubKeyhash => IPreconfRegistry.Validator validator) internal validators;

    uint256 internal nextPreconferIndex = 1;

    function registerPreconfer(address preconfer) external {
        preconferToIndex[preconfer] = nextPreconferIndex;
        indexToPreconfer[nextPreconferIndex++] = preconfer;
    }

    function addValidator(
        bytes memory pubKey,
        address preconfer,
        uint40 validSince,
        uint40 validUntil
    )
        external
    {
        bytes32 key = keccak256(abi.encodePacked(bytes16(0), pubKey));
        validators[key] = IPreconfRegistry.Validator(preconfer, validSince, validUntil);
    }

    function getNextPreconferIndex() external view returns (uint256) {
        return nextPreconferIndex;
    }

    function getPreconferIndex(address preconfer) external view returns (uint256) {
        return preconferToIndex[preconfer];
    }

    function getPreconferAtIndex(uint256 index) external view returns (address) {
        return indexToPreconfer[index];
    }

    function getValidator(bytes32 pubKeyHash)
        external
        view
        returns (IPreconfRegistry.Validator memory)
    {
        return validators[pubKeyHash];
    }
}
