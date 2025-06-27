// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";

abstract contract CompareGasTest is Test {
    function measureGas(
        string memory _oldLabel,
        function() _oldApproach,
        string memory _newLabel,
        function() _newApproach
    )
        internal
    {
        uint256 startGas = gasleft();
        _oldApproach();
        uint256 endGas = gasleft();
        uint256 oldApproachGas = startGas - endGas;
        console.log(string.concat("old (", _oldLabel, "):\t"), oldApproachGas);

        startGas = gasleft();
        _newApproach();
        endGas = gasleft();
        uint256 newApproachGas = startGas - endGas;
        console.log(string.concat("new (", _newLabel, "):\t"), newApproachGas);
        console.log("new - old: ", int256(newApproachGas) - int256(oldApproachGas));
        console.log("new / old): ", (10_000 * newApproachGas) / oldApproachGas, "%%");
    }
}
