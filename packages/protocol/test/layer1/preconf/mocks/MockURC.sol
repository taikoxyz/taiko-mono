// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@eth-fabric/urc/IRegistry.sol";

contract MockURC {
    mapping(bytes32 => IRegistry.OperatorData) internal operatorData;
    mapping(bytes32 => mapping(address => IRegistry.SlasherCommitment)) internal slasherCommitments;
    mapping(bytes32 => mapping(uint256 => uint256)) internal historicalCollateral;
    mapping(bytes32 => uint256[]) internal timestamps;

    function getOperatorData(bytes32 _registrationRoot)
        external
        view
        returns (IRegistry.OperatorData memory)
    {
        return operatorData[_registrationRoot];
    }

    function getHistoricalCollateral(
        bytes32 _registrationRoot,
        uint256 _timestamp
    )
        external
        view
        returns (uint256)
    {
        uint256[] storage timestampArray = timestamps[_registrationRoot];

        if (timestampArray.length == 0) {
            return 0;
        }

        uint256 left = 0;
        uint256 right = timestampArray.length - 1;
        uint256 result = 0;

        while (left <= right) {
            uint256 mid = left + (right - left) / 2;

            if (timestampArray[mid] <= _timestamp) {
                result = timestampArray[mid];
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }

        return historicalCollateral[_registrationRoot][result];
    }

    function getSlasherCommitment(
        bytes32 _registrationRoot,
        address _slasher
    )
        external
        view
        returns (IRegistry.SlasherCommitment memory)
    {
        return slasherCommitments[_registrationRoot][_slasher];
    }

    function setOperatorData(
        bytes32 _registrationRoot,
        address _owner,
        uint256 _collateralWei,
        uint256 _numKeys,
        uint256 _registeredAt,
        uint256 _unregisteredAt,
        uint256 _slashedAt
    )
        external
    {
        operatorData[_registrationRoot] = IRegistry.OperatorData({
            owner: _owner,
            collateralWei: uint80(_collateralWei),
            numKeys: uint16(_numKeys),
            registeredAt: uint48(_registeredAt),
            unregisteredAt: uint48(_unregisteredAt),
            slashedAt: uint48(_slashedAt),
            deleted: false,
            equivocated: false
        });
    }

    function setSlasherCommitment(
        bytes32 _registrationRoot,
        address _slasher,
        uint256 _optedInAt,
        uint256 _optedOutAt,
        address _committer
    )
        external
    {
        slasherCommitments[_registrationRoot][_slasher] = IRegistry.SlasherCommitment({
            optedInAt: uint48(_optedInAt),
            optedOutAt: uint48(_optedOutAt),
            committer: _committer,
            slashed: false
        });
    }

    function setHistoricalCollateral(
        bytes32 _registrationRoot,
        uint256 _timestamp,
        uint256 _collateral
    )
        external
    {
        historicalCollateral[_registrationRoot][_timestamp] = _collateral;

        // Add timestamp to sorted array if not already present
        uint256[] storage timestampArray = timestamps[_registrationRoot];
        bool exists = false;

        for (uint256 i = 0; i < timestampArray.length; i++) {
            if (timestampArray[i] == _timestamp) {
                exists = true;
                break;
            }
        }

        if (!exists) {
            timestampArray.push(_timestamp);

            // Sort the array (simple insertion sort for small arrays)
            for (uint256 i = 1; i < timestampArray.length; i++) {
                uint256 key = timestampArray[i];
                int256 j = int256(i) - 1;

                while (j >= 0 && timestampArray[uint256(j)] > key) {
                    timestampArray[uint256(j) + 1] = timestampArray[uint256(j)];
                    j--;
                }
                timestampArray[uint256(j) + 1] = key;
            }
        }
    }

    function isOptedIntoSlasher(
        bytes32 _registrationRoot,
        address _slasher
    )
        external
        view
        returns (bool)
    {
        IRegistry.SlasherCommitment memory commitment =
            slasherCommitments[_registrationRoot][_slasher];
        return commitment.optedInAt != 0 && commitment.optedInAt < block.timestamp
            && (commitment.optedOutAt == 0 || commitment.optedOutAt > block.timestamp);
    }
}
