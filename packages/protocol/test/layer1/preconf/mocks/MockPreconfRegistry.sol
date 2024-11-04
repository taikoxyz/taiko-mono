// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockPreconfRegistry {
    struct Validator {
        address preconfer;
        uint40 startProposingAt;
        uint40 stopProposingAt;
    }

    mapping(address preconfer => uint256 index) internal preconferToIndex;
    mapping(uint256 index => address preconfer) internal indexToPreconfer;
    mapping(bytes32 pubKeyhash => Validator validator) internal validators;

    uint256 internal nextPreconferIndex = 1;

    function registerPreconfer(address preconfer) external {
        uint256 _nextPreconferIndex = nextPreconferIndex;

        preconferToIndex[preconfer] = _nextPreconferIndex;
        indexToPreconfer[_nextPreconferIndex] = preconfer;

        unchecked {
            nextPreconferIndex = _nextPreconferIndex + 1;
        }
    }

    function addValidator(
        bytes memory pubKey,
        address preconfer,
        uint256 startProposingAt,
        uint256 stopProposingAt
    )
        external
    {
        bytes32 key = keccak256(abi.encodePacked(bytes16(0), pubKey));
        validators[key] = Validator(preconfer, uint40(startProposingAt), uint40(stopProposingAt));
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

    function getValidator(bytes32 pubKeyHash) external view returns (Validator memory) {
        return validators[pubKeyHash];
    }
}
