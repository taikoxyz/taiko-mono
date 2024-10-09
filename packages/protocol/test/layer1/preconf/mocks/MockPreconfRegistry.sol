// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/IPreconfRegistry.sol";

contract MockPreconfRegistry {
    mapping(address preconfer => uint256 index) public getPreconferIndex;
    mapping(uint256 index => address preconfer) internal getPreconferAtIndex;
    mapping(bytes32 pubKeyhash => IPreconfRegistry.Validator validator) internal getValidator;

    uint256 internal nextPreconferIndex = 1;

    function registerPreconfer(address preconfer) external {
        getPreconferIndex[preconfer] = nextPreconferIndex;
        getPreconferAtIndex[nextPreconferIndex++] = preconfer;
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
        getValidator[key] = IPreconfRegistry.Validator(preconfer, validSince, validUntil);
    }

    function getNextPreconferIndex() external view returns (uint256) {
        return nextPreconferIndex;
    }
}
